import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/pc_health_prediction.dart';
import '../models/pc_health_record.dart';

/// Syswatch predictive-maintenance algorithm.
///
/// This is an explainable statistical/rule-based predictor. It does not use
/// AI, machine learning, the internet, or SQL. It stores recent health
/// snapshots locally on the Staff PC and estimates future risk from:
///
///   1. repeated component failures,
///   2. worsening failure frequency,
///   3. consecutive failures,
///   4. robust CPU/RAM/storage trends when numeric metrics are available,
///   5. current severity as supporting evidence,
///   6. recency weighting so newer observations matter more.
///
/// Important: an exact time-to-problem is shown ONLY when a numeric metric
/// (CPU/RAM/storage) has enough historical time span for a real threshold
/// forecast. Binary healthy/unhealthy checks can raise risk, but do not invent
/// a failure date.
class PcHealthPredictionService {
  PcHealthPredictionService._();

  static final PcHealthPredictionService instance =
      PcHealthPredictionService._();

  /// Three samples are enough to start showing a basic recurrence risk.
  /// Five or more is much better and is stated in the summary.
  static const int minimumSamples = 3;
  static const int recommendedSamples = 5;
  static const int maxSamplesPerPc = 180;

  /// Numeric "days until threshold" forecasts are suppressed when all points
  /// are too close together. This prevents a few readings taken minutes apart
  /// from producing absurd "failure tomorrow" estimates.
  static const Duration minimumMetricTrendSpan = Duration(hours: 24);

  /// Only recent history is used for the active prediction.
  static const Duration predictionLookback = Duration(days: 30);

  final Map<String, List<_HealthSnapshot>> _history = {};
  bool _initialized = false;
  bool _saving = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final file = await _historyFile();
      if (!await file.exists()) return;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      for (final entry in decoded.entries) {
        if (entry.value is! List) continue;

        final items = <_HealthSnapshot>[];
        for (final item in entry.value as List) {
          if (item is! Map) continue;
          try {
            items.add(
              _HealthSnapshot.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          } catch (_) {
            // Ignore one malformed row instead of breaking PC Health.
          }
        }

        items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (items.length > maxSamplesPerPc) {
          _history[entry.key.toString()] =
              items.sublist(items.length - maxSamplesPerPc);
        } else {
          _history[entry.key.toString()] = items;
        }
      }
    } catch (_) {
      // Prediction persistence must never stop the main application.
    }
  }

  Future<void> ingest(List<PcHealthRecord> records) async {
    await initialize();
    var changed = false;

    for (final record in records) {
      final key = _key(record);
      final sample = _HealthSnapshot.fromRecord(record);
      final list = _history.putIfAbsent(key, () => <_HealthSnapshot>[]);

      // A refresh of the same API row must not be counted as another health
      // observation. The generated ID includes the server timestamp/details.
      if (list.any((existing) => existing.id == sample.id)) continue;

      list.add(sample);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (list.length > maxSamplesPerPc) {
        list.removeRange(0, list.length - maxSamplesPerPc);
      }
      changed = true;
    }

    if (changed) await _save();
  }

  PcHealthPrediction predictFor(PcHealthRecord record) {
    final key = _key(record);
    final history = List<_HealthSnapshot>.from(
      _history[key] ?? const <_HealthSnapshot>[],
    )..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final current = _HealthSnapshot.fromRecord(record);
    if (!history.any((item) => item.id == current.id)) {
      history.add(current);
      history.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    if (history.length < minimumSamples) {
      return PcHealthPrediction.collecting(
        history.length,
        requiredCount: minimumSamples,
      );
    }

    final recent = _recentHistory(history);

    final components = <PcComponentPrediction>[
      _predictBooleanComponent(
        name: 'CPU',
        history: recent,
        selector: (s) => s.cpuOk,
        metricSelector: (s) => s.cpuUsage,
        metricThreshold: 90,
        increasingIsBad: true,
      ),
      _predictBooleanComponent(
        name: 'RAM',
        history: recent,
        selector: (s) => s.ramOk,
        metricSelector: (s) => s.ramUsage,
        metricThreshold: 90,
        increasingIsBad: true,
      ),
      _predictBooleanComponent(
        name: 'Disk',
        history: recent,
        selector: (s) => s.diskOk,
      ),
      _predictBooleanComponent(
        name: 'Storage health',
        history: recent,
        selector: (s) => s.storageHealthOk,
      ),
      _predictStorage(recent),
      _predictBooleanComponent(
        name: 'Ethernet/LAN',
        history: recent,
        selector: (s) => s.networkOk,
      ),
      _predictPeripherals(recent),
    ];

    // Critical components carry more predictive weight than optional devices.
    const weights = <String, double>{
      'CPU': 0.18,
      'RAM': 0.18,
      'Disk': 0.20,
      'Storage health': 0.18,
      'Storage space': 0.14,
      'Ethernet/LAN': 0.07,
      'Peripherals': 0.05,
    };

    double overall = 0;
    for (final component in components) {
      overall += component.riskScore * (weights[component.component] ?? 0);
    }

    // Current severity is supporting evidence, but it no longer dominates the
    // prediction. A single current fault should not masquerade as a reliable
    // future forecast.
    final latest = recent.last;
    if (latest.statusSeverity >= 3) {
      overall += 6;
    } else if (latest.statusSeverity == 2) {
      overall += 3;
    }

    // Add a small bonus only when the overall instantaneous risk itself is
    // clearly worsening over time.
    final riskSlope = _robustDailySlope(
      recent,
      (s) => s.instantRisk.toDouble(),
      requireMinimumSpan: false,
    );
    if (riskSlope > 6) {
      overall += 7;
    } else if (riskSlope > 2) {
      overall += 3;
    }

    final overallScore = overall.round().clamp(0, 100).toInt();
    final level = _riskLevel(overallScore);
    final trend = _overallTrend(recent, riskSlope);

    // Exact windows are permitted only when a component has a real numerical
    // threshold forecast. Binary recurrence alone never creates a fake date.
    final estimated = components
        .where((c) => c.estimatedDays != null && c.estimatedDays! >= 0)
        .map((c) => c.estimatedDays!)
        .where((days) => days <= 90)
        .toList();
    final earliestDays = estimated.isEmpty ? null : estimated.reduce(min);

    final window = _predictionWindow(
      riskLevel: level,
      earliestDays: earliestDays,
    );

    final sortedComponents = List<PcComponentPrediction>.from(components)
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

    final reasons = sortedComponents
        .where((item) => item.riskScore >= 25)
        .take(3)
        .map((item) => item.message)
        .toList();

    final strongest = sortedComponents
        .where((item) => item.riskScore >= 25)
        .take(2)
        .map((e) => e.component)
        .toList();

    final summary = _summary(
      riskScore: overallScore,
      riskLevel: level,
      trend: trend,
      strongest: strongest,
      window: window,
      sampleCount: recent.length,
      span: recent.last.timestamp.difference(recent.first.timestamp),
      hasTimedForecast: earliestDays != null,
    );

    return PcHealthPrediction(
      ready: true,
      historyCount: recent.length,
      riskScore: overallScore,
      riskLevel: level,
      trend: trend,
      predictedProblemWindow: window,
      summary: summary,
      reasons: reasons,
      components: components,
    );
  }

  Future<void> clearHistory() async {
    _history.clear();
    try {
      final file = await _historyFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  List<_HealthSnapshot> _recentHistory(List<_HealthSnapshot> history) {
    if (history.isEmpty) return const [];
    final cutoff = history.last.timestamp.subtract(predictionLookback);
    final recent = history.where((s) => !s.timestamp.isBefore(cutoff)).toList();

    // Preserve enough samples even when timestamps in test data are unusual.
    if (recent.length >= minimumSamples) return recent;
    return history.length > 30 ? history.sublist(history.length - 30) : history;
  }

  PcComponentPrediction _predictBooleanComponent({
    required String name,
    required List<_HealthSnapshot> history,
    required bool? Function(_HealthSnapshot) selector,
    double? Function(_HealthSnapshot)? metricSelector,
    double? metricThreshold,
    bool increasingIsBad = true,
  }) {
    final available = history.where((s) => selector(s) != null).toList();
    if (available.isEmpty) {
      return PcComponentPrediction(
        component: name,
        riskScore: 0,
        riskLevel: 'low',
        message: '$name has no usable health history yet.',
      );
    }

    final window = available.length > 12
        ? available.sublist(available.length - 12)
        : available;

    final weightedFailureRate = _recencyWeightedFailureRate(window, selector);
    final rawFailures = window.where((s) => selector(s) == false).length;
    final consecutiveFailures = _consecutiveFailures(window, selector);
    final latestFailed = selector(window.last) == false;

    var score = (weightedFailureRate * 55).round();

    // Repeated / consecutive faults are stronger predictive evidence than a
    // single isolated current fault.
    if (consecutiveFailures >= 3) {
      score += 28;
    } else if (consecutiveFailures == 2) {
      score += 18;
    } else if (latestFailed) {
      score += 8;
    }

    final worsening = _failureRateChange(window, selector);
    if (worsening >= 0.30) {
      score += 18;
    } else if (worsening >= 0.15) {
      score += 9;
    }

    double? estimatedDays;
    if (metricSelector != null && metricThreshold != null) {
      final metricRows = window.where((s) => metricSelector(s) != null).toList();
      if (metricRows.length >= minimumSamples &&
          _hasMinimumMetricSpan(metricRows)) {
        final current = _median(
          metricRows
              .sublist(max(0, metricRows.length - 3))
              .map((s) => metricSelector(s)!)
              .toList(),
        );
        final slope = _robustDailySlope(
          metricRows,
          (s) => metricSelector(s)!,
        );
        final badSlope = increasingIsBad ? slope : -slope;

        // Persistently high utilization matters more than one spike.
        final recentMetricValues = metricRows
            .sublist(max(0, metricRows.length - 3))
            .map((s) => metricSelector(s)!)
            .toList();
        final thresholdHits = recentMetricValues
            .where((v) => increasingIsBad ? v >= metricThreshold : v <= metricThreshold)
            .length;

        if (thresholdHits >= 2) {
          score += 28;
          estimatedDays = 0;
        } else if (badSlope > 0.05) {
          final distance = increasingIsBad
              ? metricThreshold - current
              : current - metricThreshold;
          if (distance > 0) {
            final days = distance / badSlope;
            if (days.isFinite && days >= 0 && days <= 365) {
              estimatedDays = days;
              if (days <= 7) {
                score += 28;
              } else if (days <= 14) {
                score += 20;
              } else if (days <= 30) {
                score += 12;
              } else if (days <= 60) {
                score += 6;
              }
            }
          }
        }
      }
    }

    score = score.clamp(0, 100).toInt();

    String message;
    if (estimatedDays == 0) {
      message = '$name has persistently reached its warning threshold.';
    } else if (estimatedDays != null && estimatedDays <= 90) {
      message = '$name has a sustained trend toward its warning threshold in about ${_daysText(estimatedDays)} if the current trend continues.';
    } else if (consecutiveFailures >= 2) {
      message = '$name has repeated consecutive failures and has an elevated recurrence risk.';
    } else if (rawFailures >= 2) {
      message = '$name has intermittent recurring failures in recent health checks.';
    } else if (latestFailed) {
      message = '$name currently reports an isolated problem; more history is needed before treating it as a predictive trend.';
    } else {
      message = '$name is stable in recent health checks.';
    }

    return PcComponentPrediction(
      component: name,
      riskScore: score,
      riskLevel: _riskLevel(score),
      estimatedDays: estimatedDays,
      message: message,
    );
  }

  PcComponentPrediction _predictStorage(List<_HealthSnapshot> history) {
    final recurrence = _predictBooleanComponent(
      name: 'Storage space',
      history: history,
      selector: (s) => s.storageCapacityOk,
    );

    final metricRows = history
        .where(
          (s) =>
              s.storageFreeGb != null &&
              s.storageTotalGb != null &&
              s.storageTotalGb! > 0,
        )
        .toList();

    if (metricRows.length < minimumSamples || !_hasMinimumMetricSpan(metricRows)) {
      return recurrence;
    }

    final recentRows = metricRows.length > 12
        ? metricRows.sublist(metricRows.length - 12)
        : metricRows;

    final lastThree = recentRows.sublist(max(0, recentRows.length - 3));
    final currentFree = _median(lastThree.map((s) => s.storageFreeGb!).toList());
    final total = _median(lastThree.map((s) => s.storageTotalGb!).toList());
    if (total <= 0) return recurrence;

    final threshold = total * 0.10;
    final freePercent = currentFree / total * 100;
    final slope = _robustDailySlope(recentRows, (s) => s.storageFreeGb!);

    var score = recurrence.riskScore;
    double? estimatedDays;

    if (freePercent <= 10) {
      score += 35;
      estimatedDays = 0;
    } else if (freePercent <= 15) {
      score += 22;
    } else if (freePercent <= 20) {
      score += 10;
    }

    if (slope < -0.05 && currentFree > threshold) {
      final days = (currentFree - threshold) / slope.abs();
      if (days.isFinite && days >= 0 && days <= 365) {
        estimatedDays = days;
        if (days <= 7) {
          score += 30;
        } else if (days <= 14) {
          score += 22;
        } else if (days <= 30) {
          score += 14;
        } else if (days <= 60) {
          score += 7;
        }
      }
    }

    score = score.clamp(0, 100).toInt();

    String message;
    if (estimatedDays == 0) {
      message = 'Storage free space is persistently at or below the 10% warning threshold.';
    } else if (estimatedDays != null && estimatedDays <= 90) {
      message = 'Free storage has a sustained decline and may reach the 10% free-space threshold in about ${_daysText(estimatedDays)}.';
    } else if (recurrence.riskScore >= 25) {
      message = recurrence.message;
    } else {
      message = 'Storage capacity is stable with no reliable near-term threshold crossing detected.';
    }

    return PcComponentPrediction(
      component: 'Storage space',
      riskScore: score,
      riskLevel: _riskLevel(score),
      estimatedDays: estimatedDays,
      message: message,
    );
  }

  PcComponentPrediction _predictPeripherals(List<_HealthSnapshot> history) {
    final recent = history.length > 12
        ? history.sublist(history.length - 12)
        : history;

    var totalWeight = 0.0;
    var failedWeight = 0.0;
    var latestFailures = 0;

    for (var i = 0; i < recent.length; i++) {
      // Newer snapshots get more weight.
      final weight = 1.0 + (i / max(1, recent.length - 1));
      final states = <bool?>[
        recent[i].keyboardOk,
        recent[i].mouseOk,
        recent[i].monitorOk,
        recent[i].webcamOk,
        recent[i].printerOk,
        recent[i].headsetOk,
      ];
      for (final state in states) {
        if (state == null) continue;
        totalWeight += weight;
        if (!state) failedWeight += weight;
      }
    }

    for (final state in <bool?>[
      recent.last.keyboardOk,
      recent.last.mouseOk,
      recent.last.monitorOk,
      recent.last.webcamOk,
      recent.last.printerOk,
      recent.last.headsetOk,
    ]) {
      if (state == false) latestFailures++;
    }

    if (totalWeight == 0) {
      return const PcComponentPrediction(
        component: 'Peripherals',
        riskScore: 0,
        riskLevel: 'low',
        message: 'No peripheral history is available.',
      );
    }

    final rate = failedWeight / totalWeight;
    var score = (rate * 65).round();

    // A current peripheral issue is evidence, but repeated history matters more.
    score += min(15, latestFailures * 5).toInt();
    score = score.clamp(0, 100).toInt();

    final message = rate >= 0.25
        ? 'Repeated peripheral disconnects are occurring in recent health checks.'
        : latestFailures > 0
            ? '$latestFailures peripheral ${latestFailures == 1 ? 'problem is' : 'problems are'} currently detected, but recurrence history is still limited.'
            : 'Peripheral connections are stable.';

    return PcComponentPrediction(
      component: 'Peripherals',
      riskScore: score,
      riskLevel: _riskLevel(score),
      message: message,
    );
  }

  double _recencyWeightedFailureRate(
    List<_HealthSnapshot> rows,
    bool? Function(_HealthSnapshot) selector,
  ) {
    var failed = 0.0;
    var total = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final value = selector(rows[i]);
      if (value == null) continue;
      final weight = 1.0 + (i / max(1, rows.length - 1));
      total += weight;
      if (!value) failed += weight;
    }
    return total == 0 ? 0 : failed / total;
  }

  int _consecutiveFailures(
    List<_HealthSnapshot> rows,
    bool? Function(_HealthSnapshot) selector,
  ) {
    var count = 0;
    for (var i = rows.length - 1; i >= 0; i--) {
      final value = selector(rows[i]);
      if (value == false) {
        count++;
      } else if (value == true) {
        break;
      }
    }
    return count;
  }

  double _failureRateChange(
    List<_HealthSnapshot> rows,
    bool? Function(_HealthSnapshot) selector,
  ) {
    if (rows.length < 4) return 0;
    final split = rows.length ~/ 2;
    final older = rows.sublist(0, split);
    final newer = rows.sublist(split);

    double rate(List<_HealthSnapshot> items) {
      final usable = items.where((s) => selector(s) != null).toList();
      if (usable.isEmpty) return 0;
      return usable.where((s) => selector(s) == false).length / usable.length;
    }

    return rate(newer) - rate(older);
  }

  bool _hasMinimumMetricSpan(List<_HealthSnapshot> rows) {
    if (rows.length < minimumSamples) return false;
    return rows.last.timestamp.difference(rows.first.timestamp) >=
        minimumMetricTrendSpan;
  }

  /// Robust Theil-Sen-style median slope.
  ///
  /// Compared with ordinary least squares, a single CPU/RAM/storage spike has
  /// much less influence on the forecast.
  double _robustDailySlope(
    List<_HealthSnapshot> rows,
    double Function(_HealthSnapshot) value, {
    bool requireMinimumSpan = true,
  }) {
    if (rows.length < 2) return 0;
    if (requireMinimumSpan && !_hasMinimumMetricSpan(rows)) return 0;

    final slopes = <double>[];
    for (var i = 0; i < rows.length - 1; i++) {
      for (var j = i + 1; j < rows.length; j++) {
        final minutes = rows[j].timestamp.difference(rows[i].timestamp).inMinutes;
        if (minutes <= 0) continue;
        final days = minutes / 1440.0;
        final slope = (value(rows[j]) - value(rows[i])) / days;
        if (slope.isFinite) slopes.add(slope);
      }
    }
    return slopes.isEmpty ? 0 : _median(slopes);
  }

  String _overallTrend(List<_HealthSnapshot> history, double riskSlope) {
    if (history.length < minimumSamples) return 'collecting';

    // Compare weighted recent and older risk instead of relying on one sample.
    final split = max(1, history.length ~/ 2);
    final older = history.sublist(0, split);
    final newer = history.sublist(split);

    final oldAvg = older.map((s) => s.instantRisk).reduce((a, b) => a + b) /
        older.length;
    final newAvg = newer.isEmpty
        ? oldAvg
        : newer.map((s) => s.instantRisk).reduce((a, b) => a + b) /
            newer.length;

    if (newAvg - oldAvg >= 12 || riskSlope >= 3) return 'declining';
    if (oldAvg - newAvg >= 12 || riskSlope <= -3) return 'improving';
    return 'stable';
  }

  String _predictionWindow({
    required String riskLevel,
    required double? earliestDays,
  }) {
    if (earliestDays != null) {
      if (earliestDays <= 1) return 'Within 24 hours / already at threshold';
      if (earliestDays <= 7) return 'Within 7 days';
      if (earliestDays <= 14) return 'Within 7–14 days';
      if (earliestDays <= 30) return 'Within 15–30 days';
      if (earliestDays <= 60) return 'Within 1–2 months';
      if (earliestDays <= 90) return 'Within 2–3 months';
    }

    if (riskLevel == 'critical' || riskLevel == 'high') {
      return 'Elevated risk — no reliable date estimate';
    }
    if (riskLevel == 'moderate') {
      return 'Monitor trend — no reliable date estimate';
    }
    return 'No immediate problem predicted';
  }

  String _summary({
    required int riskScore,
    required String riskLevel,
    required String trend,
    required List<String> strongest,
    required String window,
    required int sampleCount,
    required Duration span,
    required bool hasTimedForecast,
  }) {
    final quality = sampleCount >= recommendedSamples
        ? 'based on $sampleCount recent checks'
        : 'based on only $sampleCount checks; confidence is still limited';

    final spanHours = span.inHours;
    final spanText = spanHours >= 24
        ? '${(spanHours / 24).toStringAsFixed(spanHours >= 72 ? 0 : 1)} days'
        : '$spanHours hours';

    if (riskLevel == 'low') {
      return 'The workstation is currently stable. No significant future-risk pattern is detected $quality across $spanText. Predictive risk: $riskScore/100.';
    }

    final source = strongest.isEmpty ? 'recent health history' : strongest.join(' and ');
    final timing = hasTimedForecast
        ? window
        : 'A reliable failure date cannot be calculated from the available data.';

    if (riskLevel == 'moderate') {
      return 'The workstation has a moderate future-risk score of $riskScore/100. $source shows a recurring or worsening pattern, $quality across $spanText. $timing';
    }
    if (riskLevel == 'high') {
      return 'The workstation has a high future-risk score of $riskScore/100. $source shows a strong recurring or worsening pattern, $quality across $spanText. $timing';
    }
    return 'The workstation has a critical predictive risk score of $riskScore/100. $source shows the strongest recurring or worsening pattern, $quality across $spanText. $timing';
  }

  static String _riskLevel(int score) {
    if (score >= 75) return 'critical';
    if (score >= 50) return 'high';
    if (score >= 25) return 'moderate';
    return 'low';
  }

  static String _daysText(double days) {
    if (days < 1) return 'less than 1 day';
    if (days < 2) return '1 day';
    return '${days.round()} days';
  }

  static String _key(PcHealthRecord record) {
    if (record.workstationId.trim().isNotEmpty) {
      return record.workstationId.trim();
    }
    return '${record.roomName.trim()}::${record.pcId.trim()}';
  }

  Future<File> _historyFile() async {
    final base = Platform.environment['APPDATA']?.trim().isNotEmpty == true
        ? Platform.environment['APPDATA']!
        : (Platform.environment['USERPROFILE']?.trim().isNotEmpty == true
            ? Platform.environment['USERPROFILE']!
            : Directory.systemTemp.path);
    final dir = Directory('$base${Platform.pathSeparator}Syswatch');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(
      '${dir.path}${Platform.pathSeparator}pc_health_prediction_history.json',
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      final file = await _historyFile();
      final payload = <String, dynamic>{
        for (final entry in _history.entries)
          entry.key: entry.value.map((item) => item.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Local prediction persistence is optional.
    } finally {
      _saving = false;
    }
  }
}

class _HealthSnapshot {
  final String id;
  final DateTime timestamp;
  final int statusSeverity;
  final bool? cpuOk;
  final bool? ramOk;
  final bool? diskOk;
  final bool? storageHealthOk;
  final bool? storageCapacityOk;
  final bool? networkOk;
  final bool? keyboardOk;
  final bool? mouseOk;
  final bool? monitorOk;
  final bool? webcamOk;
  final bool? printerOk;
  final bool? headsetOk;
  final double? cpuUsage;
  final double? ramUsage;
  final double? storageFreeGb;
  final double? storageTotalGb;

  const _HealthSnapshot({
    required this.id,
    required this.timestamp,
    required this.statusSeverity,
    this.cpuOk,
    this.ramOk,
    this.diskOk,
    this.storageHealthOk,
    this.storageCapacityOk,
    this.networkOk,
    this.keyboardOk,
    this.mouseOk,
    this.monitorOk,
    this.webcamOk,
    this.printerOk,
    this.headsetOk,
    this.cpuUsage,
    this.ramUsage,
    this.storageFreeGb,
    this.storageTotalGb,
  });

  int get instantRisk {
    var score = 0;
    if (cpuOk == false) score = max(score, 85);
    if (ramOk == false) score = max(score, 80);
    if (diskOk == false) score = max(score, 90);
    if (storageHealthOk == false) score = max(score, 90);
    if (storageCapacityOk == false) score = max(score, 65);
    if (networkOk == false) score = max(score, 35);

    final peripheralFailures = <bool?>[
      keyboardOk,
      mouseOk,
      monitorOk,
      webcamOk,
      printerOk,
      headsetOk,
    ].where((e) => e == false).length;
    if (peripheralFailures >= 3) score = max(score, 45);
    if (peripheralFailures > 0) score = max(score, 25);

    if (statusSeverity >= 3) score = max(score, 90);
    if (statusSeverity == 2) score = max(score, 55);
    if (statusSeverity == 1) score = max(score, 25);
    return score.clamp(0, 100).toInt();
  }

  factory _HealthSnapshot.fromRecord(PcHealthRecord record) {
    final fields = _normalizedMap(record.details);
    final timestamp = record.lastCheck ?? DateTime.now();
    final detailsSignature = _stableDetailsSignature(record.details);
    final id = record.lastCheck != null
        ? '${timestamp.toIso8601String()}|${record.status}|$detailsSignature'
        : '${record.id}|${record.status}|$detailsSignature';

    return _HealthSnapshot(
      id: id,
      timestamp: timestamp,
      statusSeverity: _severity(record.status, fields['severity']),
      cpuOk: _bool(fields['cpuok']),
      ramOk: _bool(fields['ramok']),
      diskOk: _bool(fields['diskok']),
      storageHealthOk: _bool(fields['storagehealthok']),
      storageCapacityOk: _bool(fields['storagecapacityok']),
      networkOk: _bool(fields['networkok']),
      keyboardOk: _bool(fields['keyboardok']),
      mouseOk: _bool(fields['mouseok']),
      monitorOk: _bool(fields['monitorok']),
      webcamOk: _bool(fields['webcamok']),
      printerOk: _bool(fields['printerok']),
      headsetOk: _bool(fields['headsetok']),
      cpuUsage: _numberFrom(
        fields,
        const ['cpuusage', 'cpuusagepercent', 'cpupercent'],
      ),
      ramUsage: _numberFrom(
        fields,
        const [
          'ramusage',
          'ramusagepercent',
          'rampercent',
          'memoryusage',
          'memorypercent',
        ],
      ),
      storageFreeGb: _numberFrom(
        fields,
        const ['storagefreegb', 'freestoragegb', 'diskfreegb', 'freegb'],
      ),
      storageTotalGb: _numberFrom(
        fields,
        const ['storagetotalgb', 'totalstoragegb', 'disktotalgb', 'totalgb'],
      ),
    );
  }

  factory _HealthSnapshot.fromJson(Map<String, dynamic> json) {
    return _HealthSnapshot(
      id: (json['id'] ?? '').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      statusSeverity: _int(json['statusSeverity']),
      cpuOk: _nullableBool(json['cpuOk']),
      ramOk: _nullableBool(json['ramOk']),
      diskOk: _nullableBool(json['diskOk']),
      storageHealthOk: _nullableBool(json['storageHealthOk']),
      storageCapacityOk: _nullableBool(json['storageCapacityOk']),
      networkOk: _nullableBool(json['networkOk']),
      keyboardOk: _nullableBool(json['keyboardOk']),
      mouseOk: _nullableBool(json['mouseOk']),
      monitorOk: _nullableBool(json['monitorOk']),
      webcamOk: _nullableBool(json['webcamOk']),
      printerOk: _nullableBool(json['printerOk']),
      headsetOk: _nullableBool(json['headsetOk']),
      cpuUsage: _double(json['cpuUsage']),
      ramUsage: _double(json['ramUsage']),
      storageFreeGb: _double(json['storageFreeGb']),
      storageTotalGb: _double(json['storageTotalGb']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'statusSeverity': statusSeverity,
        'cpuOk': cpuOk,
        'ramOk': ramOk,
        'diskOk': diskOk,
        'storageHealthOk': storageHealthOk,
        'storageCapacityOk': storageCapacityOk,
        'networkOk': networkOk,
        'keyboardOk': keyboardOk,
        'mouseOk': mouseOk,
        'monitorOk': monitorOk,
        'webcamOk': webcamOk,
        'printerOk': printerOk,
        'headsetOk': headsetOk,
        'cpuUsage': cpuUsage,
        'ramUsage': ramUsage,
        'storageFreeGb': storageFreeGb,
        'storageTotalGb': storageTotalGb,
      };
}

Map<String, dynamic> _normalizedMap(dynamic value) {
  if (value is! Map) return const {};
  return <String, dynamic>{
    for (final entry in value.entries)
      entry.key
          .toString()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase(): entry.value,
  };
}

String _stableDetailsSignature(dynamic value) {
  try {
    if (value is Map) {
      final sorted = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return jsonEncode({
        for (final entry in sorted) entry.key.toString(): entry.value,
      });
    }
    return jsonEncode(value);
  } catch (_) {
    return value?.toString() ?? '';
  }
}

int _severity(String status, dynamic detailSeverity) {
  final value = '${detailSeverity ?? ''} $status'.toLowerCase();
  if (value.contains('critical') ||
      value.contains('broken') ||
      value.contains('failed')) {
    return 3;
  }
  if (value.contains('high') || value.contains('degraded')) return 2;
  if (value.contains('minor') || value.contains('warning')) return 1;
  return 0;
}

bool? _bool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (value.toString().trim().toLowerCase()) {
    case 'true':
    case '1':
    case 'yes':
    case 'ok':
    case 'healthy':
    case 'connected':
    case 'working':
      return true;
    case 'false':
    case '0':
    case 'no':
    case 'failed':
    case 'unhealthy':
    case 'disconnected':
    case 'broken':
      return false;
  }
  return null;
}

bool? _nullableBool(dynamic value) => value == null ? null : _bool(value);

double? _numberFrom(Map<String, dynamic> fields, List<String> keys) {
  for (final key in keys) {
    if (!fields.containsKey(key)) continue;
    final parsed = _double(fields[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final cleaned = value
      .toString()
      .replaceAll('%', '')
      .replaceAll(RegExp(r'[^0-9.\-]'), '')
      .trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

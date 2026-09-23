import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/fault_report.dart';
import '../models/maintenance_record.dart';
import '../models/pc_health_prediction.dart';
import '../models/pc_health_record.dart';
import 'staff_service.dart';

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
///   6. real-time recency weighting so newer observations matter more,
///   7. polling-rate normalization so rapid refreshes do not inflate risk,
///   8. recovery streaks so repaired PCs lose old risk gradually,
///   9. trend reliability checks that reject unstable/outlier-driven forecasts,
///  10. confidence scoring based on sample count, time span, and data coverage,
///  11. a per-PC normal baseline,
///  12. separate failure episodes instead of raw failure counts,
///  13. repair/maintenance-aware risk resets and recurrence penalties,
///  14. optional MariaDB-backed health history shared by every Staff PC,
///  15. room peer comparison when enough comparable workstations exist.
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

  /// Newer observations matter more, but weighting is based on real elapsed
  /// time instead of list position. This avoids over-counting PCs that report
  /// much more frequently than others.
  static const Duration recencyHalfLife = Duration(days: 7);

  /// Very frequent polling can otherwise make one continuous outage look like
  /// many independent failures. Boolean recurrence analysis keeps only the
  /// latest state inside each one-hour bucket.
  static const Duration recurrenceBucket = Duration(hours: 1);

  /// Numeric trend analysis keeps at most one representative sample per 30
  /// minutes. This reduces noise while retaining useful CPU/RAM/storage trends.
  static const Duration metricBucket = Duration(minutes: 30);

  static const double maximumTimedForecastDays = 90;
  static const double minimumBadTrendAgreement = 0.68;

  // Overall condition should not be labelled "declining" because of tiny,
  // normal day-to-day movement. Component-level forecasting can still react
  // to slow movement when a metric is already close to its warning threshold,
  // but the overall trend requires a material rate of change.
  static const double minimumCpuRamOverallTrendPerDay = 1.0;
  static const double minimumStorageOverallTrendGbPerDay = 1.0;

  /// A long gap between two failed checks means the algorithm cannot safely
  /// assume that both checks belong to one continuous outage.
  static const Duration failureEpisodeGap = Duration(hours: 6);

  /// Per-PC baselines require enough time-separated observations to describe
  /// what is normal for that workstation.
  static const int baselineMinimumSamples = 6;
  static const Duration baselineMinimumSpan = Duration(days: 3);

  /// If a recently repaired component becomes unhealthy again, the predictor
  /// raises recurrence risk because the previous repair may not have solved
  /// the root cause.
  static const Duration repairRecurrenceWindow = Duration(days: 30);
  static const Duration repeatedRepairLookback = Duration(days: 90);

  /// Server history does not need to be downloaded every 15-second dashboard
  /// refresh. Current status is still ingested immediately.
  static const Duration serverHistoryRefreshInterval = Duration(minutes: 5);

  final Map<String, List<_HealthSnapshot>> _history = {};
  final Map<String, List<_MaintenanceContext>> _maintenanceByPc = {};
  final Map<String, List<_RepairContext>> _repairsByPc = {};

  bool _initialized = false;
  bool _saving = false;
  bool _serverSyncInProgress = false;
  DateTime? _lastServerSync;

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
      // observation. Matching IDs or timestamps are treated as the same check.
      if (list.any((existing) =>
          existing.id == sample.id || existing.timestamp == sample.timestamp)) {
        continue;
      }

      list.add(sample);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (list.length > maxSamplesPerPc) {
        list.removeRange(0, list.length - maxSamplesPerPc);
      }
      changed = true;
    }

    if (changed) await _save();
  }

  /// Loads shared prediction history from the intranet server.  Failure to
  /// reach the history endpoint never prevents the normal PC Health screen
  /// from loading; the locally cached history remains a fallback.
  Future<void> syncServerHistory({bool force = false}) async {
    await initialize();
    if (_serverSyncInProgress) return;

    final now = DateTime.now();
    if (!force &&
        _lastServerSync != null &&
        now.difference(_lastServerSync!) < serverHistoryRefreshInterval) {
      return;
    }

    _serverSyncInProgress = true;
    try {
      final results = await Future.wait<dynamic>([
        StaffService.instance.listPcHealthHistory(days: predictionLookback.inDays),
        StaffService.instance.listMaintenanceHistory(),
        StaffService.instance.listFaultReports(),
      ]);

      final serverHistory = results[0] as List<PcHealthRecord>;
      final maintenance = results[1] as List<MaintenanceRecord>;
      final faults = results[2] as List<FaultReport>;

      await ingest(serverHistory);
      setMaintenanceHistory(maintenance);
      setFaultHistory(faults);
      _lastServerSync = now;
    } catch (_) {
      // Prediction must keep working from local/current data when the optional
      // history endpoint is not installed yet or the LAN is temporarily down.
    } finally {
      _serverSyncInProgress = false;
    }
  }

  void setMaintenanceHistory(List<MaintenanceRecord> records) {
    _maintenanceByPc.clear();
    for (final record in records) {
      final key = record.workstationId.trim();
      if (key.isEmpty || record.maintenanceDate == null) continue;
      final list = _maintenanceByPc.putIfAbsent(
        key,
        () => <_MaintenanceContext>[],
      );
      list.add(
        _MaintenanceContext(
          timestamp: record.maintenanceDate!,
          condition: record.overallCondition.trim().toLowerCase(),
        ),
      );
    }
    for (final list in _maintenanceByPc.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
  }

  void setFaultHistory(List<FaultReport> reports) {
    _repairsByPc.clear();
    for (final report in reports) {
      final key = report.workstationId.trim();
      if (key.isEmpty) continue;

      final repairedAt = report.teacherApprovedAt ??
          report.completedAt ??
          report.repairedAt ??
          report.handledAt;
      final resolved = report.repaired ||
          report.workflowStatus.toLowerCase() == 'resolved' ||
          report.workflowStatus.toLowerCase() == 'completed';
      if (!resolved || repairedAt == null) continue;

      final list = _repairsByPc.putIfAbsent(key, () => <_RepairContext>[]);
      list.add(
        _RepairContext(
          timestamp: repairedAt,
          component: _componentFromIssue(report.issue),
          issue: report.issue,
        ),
      );
    }
    for (final list in _repairsByPc.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
  }

  PcHealthPrediction predictFor(PcHealthRecord record) {
    final key = _key(record);
    final history = List<_HealthSnapshot>.from(
      _history[key] ?? const <_HealthSnapshot>[],
    )..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final current = _HealthSnapshot.fromRecord(record);
    if (!history.any((item) =>
        item.id == current.id || item.timestamp == current.timestamp)) {
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
    final resetBoundary = _latestResetBoundary(key);
    final activeHistory = _historyAfterBoundary(recent, resetBoundary);

    var components = <PcComponentPrediction>[
      _predictBooleanComponent(
        name: 'CPU',
        history: activeHistory,
        selector: (s) => s.cpuOk,
        metricSelector: (s) => s.cpuUsage,
        metricThreshold: 90,
        increasingIsBad: true,
      ),
      _predictBooleanComponent(
        name: 'RAM',
        history: activeHistory,
        selector: (s) => s.ramOk,
        metricSelector: (s) => s.ramUsage,
        metricThreshold: 90,
        increasingIsBad: true,
      ),
      _predictBooleanComponent(
        name: 'Disk',
        history: activeHistory,
        selector: (s) => s.diskOk,
      ),
      _predictBooleanComponent(
        name: 'Storage health',
        history: activeHistory,
        selector: (s) => s.storageHealthOk,
      ),
      _predictStorage(activeHistory),
      _predictBooleanComponent(
        name: 'Ethernet/LAN',
        history: activeHistory,
        selector: (s) => s.networkOk,
      ),
      _predictPeripherals(activeHistory),
    ];

    components = components
        .map(
          (component) => _enhanceComponentWithContext(
            component: component,
            record: record,
            key: key,
            fullHistory: recent,
            current: current,
          ),
        )
        .toList();

    final contextNotes = _predictionContextNotes(
      key: key,
      record: record,
      resetBoundary: resetBoundary,
      current: current,
    );

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
    final latest = activeHistory.last;
    if (latest.statusSeverity >= 3) {
      overall += 6;
    } else if (latest.statusSeverity == 2) {
      overall += 3;
    }

    // Overall trend uses time-bucketed snapshots so a PC that reports every
    // minute is not treated as having more evidence than a PC that reports
    // hourly.
    final trendRows = _bucketSnapshots(activeHistory, recurrenceBucket);
    final riskSlope = _robustDailySlope(
      trendRows,
      (s) => s.instantRisk.toDouble(),
      requireMinimumSpan: false,
    );
    final trendSpan = trendRows.length >= 2
        ? trendRows.last.timestamp.difference(trendRows.first.timestamp)
        : Duration.zero;

    // Short bursts of data are not allowed to create a large trend bonus.
    if (trendSpan >= const Duration(hours: 24)) {
      if (riskSlope > 6) {
        overall += 7;
      } else if (riskSlope > 2) {
        overall += 3;
      }
    }

    // Multiple independent components worsening at the same time is stronger
    // evidence of system-wide degradation than one isolated warning.
    final elevatedComponents = components.where((c) => c.riskScore >= 50).length;
    if (elevatedComponents >= 3) {
      overall += 6;
    } else if (elevatedComponents == 2) {
      overall += 3;
    }

    final warningComponents = components.where((c) => c.riskScore >= 25).length;
    if (warningComponents >= 4) {
      overall += 5;
    } else if (warningComponents == 3) {
      overall += 3;
    }

    final nearTermForecasts = components
        .where((c) => c.estimatedDays != null && c.estimatedDays! >= 0 && c.estimatedDays! <= 14)
        .length;
    if (nearTermForecasts >= 2) overall += 3;

    final maintenanceAdjustment = _maintenanceRiskAdjustment(key, current);
    overall += maintenanceAdjustment;

    final overallScore = overall.round().clamp(0, 100).toInt();
    final level = _riskLevel(overallScore);
    final metricDirection = _overallMetricDirection(activeHistory);
    final trend = _overallTrend(trendRows, riskSlope, metricDirection);
    final confidenceScore = _predictionConfidence(
      activeHistory,
      resetBoundary: resetBoundary,
    );
    final confidenceLevel = _confidenceLevel(confidenceScore);

    // Exact windows are permitted only when a component has a real numerical
    // threshold forecast. Binary recurrence alone never creates a fake date.
    final estimated = components
        .where((c) => c.estimatedDays != null && c.estimatedDays! >= 0)
        .map((c) => c.estimatedDays!)
        .where((days) => days <= maximumTimedForecastDays)
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
      sampleCount: activeHistory.length,
      span: activeHistory.last.timestamp.difference(activeHistory.first.timestamp),
      hasTimedForecast: earliestDays != null,
      confidenceScore: confidenceScore,
      confidenceLevel: confidenceLevel,
    );

    return PcHealthPrediction(
      ready: true,
      historyCount: activeHistory.length,
      riskScore: overallScore,
      riskLevel: level,
      trend: trend,
      predictedProblemWindow: window,
      summary: summary,
      reasons: reasons,
      components: components,
      contextNotes: contextNotes,
      confidenceScore: confidenceScore,
      confidenceLevel: confidenceLevel,
    );
  }

  Future<void> clearHistory() async {
    _history.clear();
    _maintenanceByPc.clear();
    _repairsByPc.clear();
    _lastServerSync = null;
    try {
      final file = await _historyFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  DateTime? _latestResetBoundary(String key) {
    final maintenance = _maintenanceByPc[key] ?? const <_MaintenanceContext>[];
    DateTime? latest;
    for (final item in maintenance) {
      if (item.condition != 'good') continue;
      if (latest == null || item.timestamp.isAfter(latest)) {
        latest = item.timestamp;
      }
    }
    return latest;
  }

  List<_HealthSnapshot> _historyAfterBoundary(
    List<_HealthSnapshot> history,
    DateTime? boundary,
  ) {
    if (boundary == null) return history;
    final after = history
        .where((item) => !item.timestamp.isBefore(boundary))
        .toList();
    // Do not throw away useful evidence until at least three post-maintenance
    // observations exist. Confidence is capped while post-maintenance evidence
    // is still sparse.
    return after.length >= minimumSamples ? after : history;
  }

  PcComponentPrediction _enhanceComponentWithContext({
    required PcComponentPrediction component,
    required PcHealthRecord record,
    required String key,
    required List<_HealthSnapshot> fullHistory,
    required _HealthSnapshot current,
  }) {
    final baseline = _baselineAssessment(component.component, fullHistory);
    final peer = _peerAssessment(
      component.component,
      record: record,
      current: current,
    );
    final repair = _repairAssessment(
      key,
      component.component,
      current,
    );

    var score = component.riskScore +
        baseline.adjustment +
        peer.adjustment +
        repair.adjustment;
    score = score.clamp(0, 100).toInt();

    final notes = <String>[
      if (baseline.message != null) baseline.message!,
      if (peer.message != null) peer.message!,
      if (repair.message != null) repair.message!,
    ];

    final message = notes.isEmpty
        ? component.message
        : '${component.message} ${notes.join(' ')}';

    return PcComponentPrediction(
      component: component.component,
      riskScore: score,
      riskLevel: _riskLevel(score),
      estimatedDays: component.estimatedDays,
      message: message,
    );
  }

  _RiskAdjustment _baselineAssessment(
    String component,
    List<_HealthSnapshot> history,
  ) {
    if (history.length < baselineMinimumSamples) {
      return const _RiskAdjustment();
    }
    final span = history.last.timestamp.difference(history.first.timestamp);
    if (span < baselineMinimumSpan) return const _RiskAdjustment();

    if (component == 'CPU' || component == 'RAM') {
      double? selector(_HealthSnapshot row) =>
          component == 'CPU' ? row.cpuUsage : row.ramUsage;
      var rows = history.where((row) => selector(row) != null).toList();
      rows = _bucketSnapshots(rows, metricBucket);
      if (rows.length < baselineMinimumSamples) {
        return const _RiskAdjustment();
      }

      final currentRows = rows.sublist(max(0, rows.length - 2));
      final baselineRows = rows.sublist(0, max(1, rows.length - 2));
      if (baselineRows.length < 4) return const _RiskAdjustment();

      final baselineValues = baselineRows.map((row) => selector(row)!).toList();
      final currentValues = currentRows.map((row) => selector(row)!).toList();
      final baseline = _median(baselineValues);
      final current = _median(currentValues);
      final mad = _medianAbsoluteDeviation(baselineValues, baseline);
      final materialDelta = max(15.0, mad * 3.0);
      final delta = current - baseline;

      if (current >= 60 && delta >= materialDelta) {
        final bonus = delta >= 35
            ? 28
            : delta >= 25
                ? 22
                : 14;
        return _RiskAdjustment(
          adjustment: bonus,
          message:
              '$component is ${delta.toStringAsFixed(0)} points above this PC\'s normal baseline (${baseline.toStringAsFixed(0)}% → ${current.toStringAsFixed(0)}%).',
        );
      }
      return const _RiskAdjustment();
    }

    if (component == 'Storage space') {
      var rows = history
          .where(
            (row) =>
                row.storageFreeGb != null &&
                row.storageTotalGb != null &&
                row.storageTotalGb! > 0,
          )
          .toList();
      rows = _bucketSnapshots(rows, metricBucket);
      if (rows.length < baselineMinimumSamples) {
        return const _RiskAdjustment();
      }

      double freePercent(_HealthSnapshot row) =>
          row.storageFreeGb! / row.storageTotalGb! * 100.0;

      final currentRows = rows.sublist(max(0, rows.length - 2));
      final baselineRows = rows.sublist(0, max(1, rows.length - 2));
      if (baselineRows.length < 4) return const _RiskAdjustment();

      final baselineValues = baselineRows.map(freePercent).toList();
      final currentValues = currentRows.map(freePercent).toList();
      final baseline = _median(baselineValues);
      final current = _median(currentValues);
      final mad = _medianAbsoluteDeviation(baselineValues, baseline);
      final materialDelta = max(10.0, mad * 3.0);
      final drop = baseline - current;

      if (current <= 35 && drop >= materialDelta) {
        final bonus = drop >= 25
            ? 24
            : drop >= 18
                ? 18
                : 10;
        return _RiskAdjustment(
          adjustment: bonus,
          message:
              'Free storage is ${drop.toStringAsFixed(0)} percentage points below this PC\'s normal baseline (${baseline.toStringAsFixed(0)}% → ${current.toStringAsFixed(0)}%).',
        );
      }
    }

    return const _RiskAdjustment();
  }

  _RiskAdjustment _peerAssessment(
    String component, {
    required PcHealthRecord record,
    required _HealthSnapshot current,
  }) {
    if (record.roomName.trim().isEmpty) return const _RiskAdjustment();

    double? currentValue;
    double? Function(_HealthSnapshot)? selector;
    bool lowerIsBad = false;

    if (component == 'CPU') {
      currentValue = current.cpuUsage;
      selector = (row) => row.cpuUsage;
    } else if (component == 'RAM') {
      currentValue = current.ramUsage;
      selector = (row) => row.ramUsage;
    } else if (component == 'Storage space') {
      if (current.storageFreeGb == null ||
          current.storageTotalGb == null ||
          current.storageTotalGb! <= 0) {
        return const _RiskAdjustment();
      }
      currentValue = current.storageFreeGb! / current.storageTotalGb! * 100.0;
      selector = (row) {
        if (row.storageFreeGb == null ||
            row.storageTotalGb == null ||
            row.storageTotalGb! <= 0) {
          return null;
        }
        return row.storageFreeGb! / row.storageTotalGb! * 100.0;
      };
      lowerIsBad = true;
    } else {
      return const _RiskAdjustment();
    }

    if (currentValue == null || selector == null) return const _RiskAdjustment();
    final comparisonValue = currentValue;
    final peerSelector = selector;

    final peerValues = <double>[];
    for (final entry in _history.entries) {
      if (entry.key == _key(record) || entry.value.isEmpty) continue;
      final candidates = entry.value
          .where(
            (row) =>
                row.roomName == record.roomName &&
                current.timestamp.difference(row.timestamp).inSeconds.abs() <=
                    const Duration(days: 7).inSeconds,
          )
          .toList();
      if (candidates.isEmpty) continue;
      candidates.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final value = peerSelector(candidates.last);
      if (value != null) peerValues.add(value);
    }

    if (peerValues.length < 3) return const _RiskAdjustment();
    final peerMedian = _median(peerValues);
    final peerMad = _medianAbsoluteDeviation(peerValues, peerMedian);

    if (!lowerIsBad) {
      final delta = comparisonValue - peerMedian;
      final threshold = max(20.0, peerMad * 3.0);
      if (comparisonValue >= 60 && delta >= threshold) {
        return _RiskAdjustment(
          adjustment: 5,
          message:
              '$component is also unusually high compared with the Room ${record.roomName} peer median (${peerMedian.toStringAsFixed(0)}%).',
        );
      }
    } else {
      final delta = peerMedian - comparisonValue;
      final threshold = max(15.0, peerMad * 3.0);
      if (comparisonValue <= 30 && delta >= threshold) {
        return _RiskAdjustment(
          adjustment: 5,
          message:
              'Free storage is also unusually low compared with the Room ${record.roomName} peer median (${peerMedian.toStringAsFixed(0)}% free).',
        );
      }
    }

    return const _RiskAdjustment();
  }

  _RiskAdjustment _repairAssessment(
    String key,
    String component,
    _HealthSnapshot current,
  ) {
    final repairs = (_repairsByPc[key] ?? const <_RepairContext>[])
        .where((item) => item.component == component || item.component == 'General')
        .toList();
    if (repairs.isEmpty) return const _RiskAdjustment();

    repairs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final latestRepair = repairs.last;
    final age = current.timestamp.difference(latestRepair.timestamp);
    if (age.isNegative) return const _RiskAdjustment();

    final currentProblem = _componentCurrentlyProblematic(component, current);

    final recentRepeatedRepairs = repairs.where((item) {
      final delta = current.timestamp.difference(item.timestamp);
      return !delta.isNegative && delta <= repeatedRepairLookback;
    }).length;

    if (age <= repairRecurrenceWindow && currentProblem) {
      var bonus = 12;
      if (recentRepeatedRepairs >= 2) {
        bonus += min(12, (recentRepeatedRepairs - 1) * 4);
      }
      return _RiskAdjustment(
        adjustment: bonus,
        message:
            '$component became problematic again after a repair ${_ageText(age)} ago${recentRepeatedRepairs >= 2 ? '; $recentRepeatedRepairs repairs were recorded in the last 90 days' : ''}.',
      );
    }

    // A recent successful repair should stop old pre-repair recurrence from
    // keeping a healthy component elevated indefinitely.
    if (age <= repairRecurrenceWindow && !currentProblem) {
      return _RiskAdjustment(
        adjustment: -20,
        message:
            'A recent $component repair is currently followed by healthy checks, so older failure risk is reduced.',
      );
    }

    return const _RiskAdjustment();
  }

  bool _componentCurrentlyProblematic(
    String component,
    _HealthSnapshot row,
  ) {
    switch (component) {
      case 'CPU':
        return row.cpuOk == false || (row.cpuUsage != null && row.cpuUsage! >= 90);
      case 'RAM':
        return row.ramOk == false || (row.ramUsage != null && row.ramUsage! >= 90);
      case 'Disk':
        return row.diskOk == false;
      case 'Storage health':
        return row.storageHealthOk == false;
      case 'Storage space':
        if (row.storageCapacityOk == false) return true;
        if (row.storageFreeGb != null &&
            row.storageTotalGb != null &&
            row.storageTotalGb! > 0) {
          return row.storageFreeGb! / row.storageTotalGb! <= 0.10;
        }
        return false;
      case 'Ethernet/LAN':
        return row.networkOk == false;
      case 'Peripherals':
        return <bool?>[
          row.keyboardOk,
          row.mouseOk,
          row.monitorOk,
          row.webcamOk,
          row.printerOk,
          row.headsetOk,
        ].any((value) => value == false);
      default:
        return row.statusSeverity > 0;
    }
  }

  double _maintenanceRiskAdjustment(String key, _HealthSnapshot current) {
    final maintenance = _maintenanceByPc[key] ?? const <_MaintenanceContext>[];
    if (maintenance.isEmpty) return 0;
    final latest = maintenance.last;
    final age = current.timestamp.difference(latest.timestamp);
    if (age.isNegative || age > const Duration(days: 90)) return 0;

    switch (latest.condition) {
      case 'critical':
        return 8;
      case 'needs_attention':
        return 4;
      case 'good':
        return current.instantRisk == 0 && age <= const Duration(days: 30)
            ? -2
            : 0;
      default:
        return 0;
    }
  }

  List<String> _predictionContextNotes({
    required String key,
    required PcHealthRecord record,
    required DateTime? resetBoundary,
    required _HealthSnapshot current,
  }) {
    final notes = <String>[];

    if (resetBoundary != null && !current.timestamp.isBefore(resetBoundary)) {
      notes.add(
        'A successful preventive-maintenance record on ${_dateText(resetBoundary)} is used as a recovery boundary when enough newer health checks exist.',
      );
    }

    final maintenance = _maintenanceByPc[key] ?? const <_MaintenanceContext>[];
    if (maintenance.isNotEmpty) {
      final latest = maintenance.last;
      notes.add(
        'Latest preventive maintenance: ${_dateText(latest.timestamp)} (${latest.condition.replaceAll('_', ' ')}).',
      );
    }

    final repairs = _repairsByPc[key] ?? const <_RepairContext>[];
    final recentRepairs = repairs.where((repair) {
      final age = current.timestamp.difference(repair.timestamp);
      return !age.isNegative && age <= repeatedRepairLookback;
    }).length;
    if (recentRepairs > 0) {
      notes.add(
        '$recentRepairs repaired fault${recentRepairs == 1 ? '' : 's'} recorded for this PC in the last 90 days.',
      );
    }

    final roomPeers = _history.values.where((items) {
      if (items.isEmpty) return false;
      return items.last.roomName == record.roomName &&
          items.last.workstationId != record.workstationId;
    }).length;
    if (roomPeers >= 3) {
      notes.add('Room-level comparison uses $roomPeers peer workstations when comparable recent metrics are available.');
    }

    return notes;
  }

  static String _componentFromIssue(String issue) {
    final text = issue.toLowerCase();
    if (text.contains('ethernet') ||
        text.contains('network') ||
        text.contains('lan')) {
      return 'Ethernet/LAN';
    }
    if (text.contains('keyboard') ||
        text.contains('mouse') ||
        text.contains('monitor') ||
        text.contains('webcam') ||
        text.contains('printer') ||
        text.contains('headset')) {
      return 'Peripherals';
    }
    if (text.contains('cpu') || text.contains('processor')) return 'CPU';
    if (text.contains('ram') || text.contains('memory')) return 'RAM';
    if (text.contains('storage') &&
        (text.contains('space') ||
            text.contains('full') ||
            text.contains('capacity') ||
            text.contains('free'))) {
      return 'Storage space';
    }
    if (text.contains('storage') ||
        text.contains('ssd') ||
        text.contains('hdd')) {
      return 'Storage health';
    }
    if (text.contains('disk')) return 'Disk';
    return 'General';
  }

  static String _dateText(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _ageText(Duration age) {
    if (age.inHours < 24) {
      final hours = max(1, age.inHours);
      return '$hours hour${hours == 1 ? '' : 's'}';
    }
    final days = max(1, age.inDays);
    return '$days day${days == 1 ? '' : 's'}';
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

    // Do not let frequent polling turn one continuous outage into dozens of
    // independent failures. Keep one representative state per hour.
    final representative = _bucketSnapshots(available, recurrenceBucket);
    final window = representative.length > 24
        ? representative.sublist(representative.length - 24)
        : representative;

    final weightedFailureRate = _recencyWeightedFailureRate(window, selector);
    final rawFailures = window.where((s) => selector(s) == false).length;
    final episodes = _failureEpisodes(window, selector);
    final consecutiveFailures = _consecutiveFailures(window, selector);
    final healthyStreak = _consecutiveHealthy(window, selector);
    final latestFailed = selector(window.last) == false;
    final currentFailureDuration = _currentFailureDuration(window, selector);

    final recurrenceEvidence = min(1.0, window.length / 4.0);
    var score = (weightedFailureRate * 48 * recurrenceEvidence).round();

    // Independent failure episodes are stronger evidence of recurrence than
    // repeated samples from the same outage.
    if (episodes >= 3) {
      score += 15;
    } else if (episodes == 2) {
      score += 8;
    }

    // Persistence is still important, but it is scored separately from
    // recurrence so polling frequency cannot inflate the result.
    if (consecutiveFailures >= 3) {
      score += 24;
    } else if (consecutiveFailures == 2) {
      score += 14;
    } else if (latestFailed) {
      score += 6;
    }

    if (latestFailed && currentFailureDuration >= const Duration(hours: 24)) {
      score += 8;
    }

    final worsening = _failureRateChange(window, selector);
    if (worsening >= 0.30) {
      score += 15;
    } else if (worsening >= 0.15) {
      score += 8;
    }

    // Recovery streaks gradually remove risk from old faults. This prevents a
    // PC that was repaired from remaining high-risk for too long.
    if (!latestFailed) {
      if (healthyStreak >= 3) {
        score -= 14;
      } else if (healthyStreak == 2) {
        score -= 7;
      }
    }
    // Recovery only removes recurrence risk. It must not cancel a new numeric
    // CPU/RAM threshold trend that is calculated below.
    score = max(0, score);

    // Recurrence has different meaning for different hardware. Repeated disk
    // or storage-health faults are stronger predictive evidence than a cable
    // that can be unplugged temporarily.
    final recurrenceScale = switch (name) {
      'Disk' => 1.18,
      'Storage health' => 1.18,
      'Ethernet/LAN' => 0.85,
      _ => 1.0,
    };
    score = (score * recurrenceScale).round();

    double? estimatedDays;
    bool unstableBadTrend = false;
    bool nearThreshold = false;

    if (metricSelector != null && metricThreshold != null) {
      var metricRows = history.where((s) => metricSelector(s) != null).toList();
      metricRows = _bucketSnapshots(metricRows, metricBucket);
      if (metricRows.length > 24) {
        metricRows = metricRows.sublist(metricRows.length - 24);
      }

      if (metricRows.length >= minimumSamples && _hasMinimumMetricSpan(metricRows)) {
        final lastRows = metricRows.sublist(max(0, metricRows.length - 3));
        final recentValues = lastRows.map((s) => metricSelector(s)!).toList();
        final current = _median(recentValues);
        final thresholdHits = recentValues
            .where((v) => increasingIsBad ? v >= metricThreshold : v <= metricThreshold)
            .length;

        final preWarningThreshold = increasingIsBad
            ? metricThreshold * 0.90
            : metricThreshold * 1.10;
        final preWarningHits = recentValues
            .where(
              (v) => increasingIsBad
                  ? v >= preWarningThreshold
                  : v <= preWarningThreshold,
            )
            .length;
        nearThreshold = preWarningHits >= 2;

        final trend = _trendStats(
          metricRows,
          (s) => metricSelector(s)!,
          increasingIsBad: increasingIsBad,
        );

        if (thresholdHits >= 2) {
          score += 28;
          estimatedDays = 0;
        } else {
          if (nearThreshold) score += 10;

          final reliableBadTrend = trend.badSlope > 0.10 &&
              trend.directionAgreement >= minimumBadTrendAgreement &&
              trend.stability >= 0.35;

          if (reliableBadTrend) {
            final distance = increasingIsBad
                ? metricThreshold - current
                : current - metricThreshold;
            if (distance > 0) {
              final days = distance / trend.badSlope;
              if (days.isFinite && days >= 0 && days <= maximumTimedForecastDays) {
                estimatedDays = days;
                if (days <= 7) {
                  score += 28;
                } else if (days <= 14) {
                  score += 20;
                } else if (days <= 30) {
                  score += 12;
                } else if (days <= 60) {
                  score += 6;
                } else {
                  score += 3;
                }
              }
            }

            if (trend.accelerating) score += 6;
          } else if (trend.badSlope > 0.10 && nearThreshold) {
            // The metric is moving in the wrong direction, but the readings are
            // too inconsistent to claim a failure date.
            score += 4;
            unstableBadTrend = true;
          }
        }
      }
    }

    score = score.clamp(0, 100).toInt();

    String message;
    if (estimatedDays == 0) {
      message = '$name has persistently reached its warning threshold.';
    } else if (estimatedDays != null) {
      message = '$name has a consistent trend toward its warning threshold in about ${_daysText(estimatedDays)} if the trend continues.';
    } else if (consecutiveFailures >= 2) {
      message = '$name has a persistent failure pattern across separate health-check periods.';
    } else if (episodes >= 2 || rawFailures >= 2) {
      message = '$name has recurring failures in recent health history.';
    } else if (latestFailed) {
      message = '$name currently reports a problem, but more history is needed before treating it as a predictive trend.';
    } else if (unstableBadTrend) {
      message = '$name is near its warning threshold and is trending upward, but the trend is not consistent enough for a reliable date estimate.';
    } else if (nearThreshold) {
      message = '$name is operating near its warning threshold and should be monitored.';
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

    var metricRows = history
        .where(
          (s) =>
              s.storageFreeGb != null &&
              s.storageTotalGb != null &&
              s.storageTotalGb! > 0,
        )
        .toList();
    metricRows = _bucketSnapshots(metricRows, metricBucket);

    if (metricRows.length < minimumSamples || !_hasMinimumMetricSpan(metricRows)) {
      return recurrence;
    }

    final recentRows = metricRows.length > 24
        ? metricRows.sublist(metricRows.length - 24)
        : metricRows;

    final lastThree = recentRows.sublist(max(0, recentRows.length - 3));
    final currentFree = _median(lastThree.map((s) => s.storageFreeGb!).toList());
    final total = _median(lastThree.map((s) => s.storageTotalGb!).toList());
    if (total <= 0) return recurrence;

    final threshold = total * 0.10;
    final freePercent = currentFree / total * 100;
    final trend = _trendStats(
      recentRows,
      (s) => s.storageFreeGb!,
      increasingIsBad: false,
    );

    var score = recurrence.riskScore;
    double? estimatedDays;
    var unstableDecline = false;

    if (freePercent <= 10) {
      score += 35;
      estimatedDays = 0;
    } else if (freePercent <= 15) {
      score += 22;
    } else if (freePercent <= 20) {
      score += 10;
    }

    final reliableDecline = trend.badSlope > 0.05 &&
        trend.directionAgreement >= minimumBadTrendAgreement &&
        trend.stability >= 0.35;

    if (estimatedDays == null && reliableDecline && currentFree > threshold) {
      final days = (currentFree - threshold) / trend.badSlope;
      if (days.isFinite && days >= 0 && days <= maximumTimedForecastDays) {
        estimatedDays = days;
        if (days <= 7) {
          score += 30;
        } else if (days <= 14) {
          score += 22;
        } else if (days <= 30) {
          score += 14;
        } else if (days <= 60) {
          score += 7;
        } else {
          score += 3;
        }
      }
      if (trend.accelerating) score += 6;
    } else if (trend.badSlope > 0.05 && freePercent <= 20) {
      unstableDecline = true;
      score += 4;
    }

    score = score.clamp(0, 100).toInt();

    String message;
    if (estimatedDays == 0) {
      message = 'Storage free space is persistently at or below the 10% warning threshold.';
    } else if (estimatedDays != null) {
      message = 'Free storage has a consistent decline and may reach the 10% free-space threshold in about ${_daysText(estimatedDays)}.';
    } else if (freePercent <= 15) {
      message = 'Storage has only ${freePercent.toStringAsFixed(1)}% free space remaining and needs attention.';
    } else if (unstableDecline) {
      message = 'Free storage is decreasing, but the rate is too inconsistent for a reliable date estimate.';
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
    final representative = _bucketSnapshots(history, recurrenceBucket);
    final recent = representative.length > 24
        ? representative.sublist(representative.length - 24)
        : representative;

    if (recent.isEmpty) {
      return const PcComponentPrediction(
        component: 'Peripherals',
        riskScore: 0,
        riskLevel: 'low',
        message: 'No peripheral history is available.',
      );
    }

    var weightedFailureFraction = 0.0;
    var totalWeight = 0.0;

    for (final row in recent) {
      final states = <bool?>[
        row.keyboardOk,
        row.mouseOk,
        row.monitorOk,
        row.webcamOk,
        row.printerOk,
        row.headsetOk,
      ].whereType<bool>().toList();
      if (states.isEmpty) continue;

      final failed = states.where((state) => !state).length;
      final fraction = failed / states.length;
      final weight = _timeWeight(row.timestamp, recent.last.timestamp);
      weightedFailureFraction += fraction * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) {
      return const PcComponentPrediction(
        component: 'Peripherals',
        riskScore: 0,
        riskLevel: 'low',
        message: 'No peripheral history is available.',
      );
    }

    final latestStates = <bool?>[
      recent.last.keyboardOk,
      recent.last.mouseOk,
      recent.last.monitorOk,
      recent.last.webcamOk,
      recent.last.printerOk,
      recent.last.headsetOk,
    ];
    final latestFailures = latestStates.where((state) => state == false).length;

    final rate = weightedFailureFraction / totalWeight;
    var score = (rate * 60).round() + min(12, latestFailures * 4).toInt();

    // If the last three representative checks are fully healthy, old
    // peripheral problems fade faster after a repair/reconnection.
    final recentThree = recent.sublist(max(0, recent.length - 3));
    final recovered = recentThree.length >= 3 && recentThree.every((row) {
      return <bool?>[
        row.keyboardOk,
        row.mouseOk,
        row.monitorOk,
        row.webcamOk,
        row.printerOk,
        row.headsetOk,
      ].every((state) => state != false);
    });
    if (recovered) score -= 10;

    score = score.clamp(0, 100).toInt();

    final message = rate >= 0.25
        ? 'Repeated peripheral problems are present across recent health-check periods.'
        : latestFailures > 0
            ? '$latestFailures peripheral ${latestFailures == 1 ? 'problem is' : 'problems are'} currently detected; more recurrence history is needed.'
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
    if (rows.isEmpty) return 0;
    final latest = rows.last.timestamp;
    var failed = 0.0;
    var total = 0.0;
    for (final row in rows) {
      final value = selector(row);
      if (value == null) continue;
      final weight = _timeWeight(row.timestamp, latest);
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

  int _consecutiveHealthy(
    List<_HealthSnapshot> rows,
    bool? Function(_HealthSnapshot) selector,
  ) {
    var count = 0;
    for (var i = rows.length - 1; i >= 0; i--) {
      final value = selector(rows[i]);
      if (value == true) {
        count++;
      } else if (value == false) {
        break;
      }
    }
    return count;
  }

  int _failureEpisodes(
    List<_HealthSnapshot> rows,
    bool? Function(_HealthSnapshot) selector,
  ) {
    var episodes = 0;
    bool previouslyFailed = false;
    DateTime? previousUsableTime;

    for (final row in rows) {
      final value = selector(row);
      if (value == null) continue;

      final separatedByLongGap = previousUsableTime != null &&
          row.timestamp.difference(previousUsableTime!) > failureEpisodeGap;

      if (value == false && (!previouslyFailed || separatedByLongGap)) {
        episodes++;
      }

      previouslyFailed = value == false;
      previousUsableTime = row.timestamp;
    }
    return episodes;
  }

  Duration _currentFailureDuration(
    List<_HealthSnapshot> rows,
    bool? Function(_HealthSnapshot) selector,
  ) {
    if (rows.isEmpty || selector(rows.last) != false) return Duration.zero;
    var start = rows.last.timestamp;
    var previous = rows.last.timestamp;

    for (var i = rows.length - 2; i >= 0; i--) {
      final value = selector(rows[i]);
      final gap = previous.difference(rows[i].timestamp);
      if (value == false && gap <= failureEpisodeGap) {
        start = rows[i].timestamp;
        previous = rows[i].timestamp;
      } else {
        break;
      }
    }
    return rows.last.timestamp.difference(start);
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

  List<_HealthSnapshot> _bucketSnapshots(
    List<_HealthSnapshot> rows,
    Duration bucket,
  ) {
    if (rows.length <= 1 || bucket.inMilliseconds <= 0) {
      return List<_HealthSnapshot>.from(rows)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    final sorted = List<_HealthSnapshot>.from(rows)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final buckets = <int, _HealthSnapshot>{};
    for (final row in sorted) {
      final key = row.timestamp.millisecondsSinceEpoch ~/ bucket.inMilliseconds;
      buckets[key] = row; // latest reading wins inside the bucket
    }
    final result = buckets.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  double _timeWeight(DateTime timestamp, DateTime latest) {
    final ageHours = max(0, latest.difference(timestamp).inMinutes) / 60.0;
    final halfLifeHours = recencyHalfLife.inHours.toDouble();
    if (halfLifeHours <= 0) return 1;
    return pow(0.5, ageHours / halfLifeHours).toDouble().clamp(0.05, 1.0).toDouble();
  }

  _TrendStats _trendStats(
    List<_HealthSnapshot> rows,
    double Function(_HealthSnapshot) value, {
    required bool increasingIsBad,
  }) {
    if (rows.length < minimumSamples || !_hasMinimumMetricSpan(rows)) {
      return const _TrendStats();
    }

    final slopes = _pairwiseDailySlopes(rows, value);
    if (slopes.isEmpty) return const _TrendStats();

    final slope = _median(slopes);
    final badSlope = increasingIsBad ? slope : -slope;
    final badDirections = slopes.where((s) => increasingIsBad ? s > 0 : s < 0).length;
    final directionAgreement = badDirections / slopes.length;
    final mad = _medianAbsoluteDeviation(slopes, slope);
    final stability = 1.0 -
        (mad / (slope.abs() + 0.25)).clamp(0.0, 1.0).toDouble();

    var accelerating = false;
    if (rows.length >= 5) {
      final split = rows.length ~/ 2;
      final older = rows.sublist(0, split + 1);
      final newer = rows.sublist(max(0, split - 1));
      final oldSlope = _robustDailySlope(older, value, requireMinimumSpan: false);
      final newSlope = _robustDailySlope(newer, value, requireMinimumSpan: false);
      final oldBad = increasingIsBad ? oldSlope : -oldSlope;
      final newBad = increasingIsBad ? newSlope : -newSlope;
      accelerating = newBad > 0.10 && newBad > oldBad + max(0.5, oldBad.abs() * 0.40);
    }

    return _TrendStats(
      slope: slope,
      badSlope: max(0.0, badSlope),
      directionAgreement: directionAgreement,
      stability: stability,
      accelerating: accelerating,
    );
  }

  List<double> _pairwiseDailySlopes(
    List<_HealthSnapshot> rows,
    double Function(_HealthSnapshot) value,
  ) {
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
    return slopes;
  }

  double _medianAbsoluteDeviation(List<double> values, double center) {
    if (values.isEmpty) return 0;
    return _median(values.map((v) => (v - center).abs()).toList());
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

  int _overallMetricDirection(List<_HealthSnapshot> history) {
    int worsening = 0;
    int improving = 0;

    void evaluate(
      double? Function(_HealthSnapshot) selector, {
      required bool increasingIsBad,
      required double minimumMaterialSlope,
    }) {
      var rows = history.where((s) => selector(s) != null).toList();
      rows = _bucketSnapshots(rows, metricBucket);
      if (rows.length < minimumSamples || !_hasMinimumMetricSpan(rows)) return;

      final bad = _trendStats(
        rows,
        (s) => selector(s)!,
        increasingIsBad: increasingIsBad,
      );

      // A reliable direction is not enough by itself. Small movement such as
      // CPU 30 -> 31 over several days or storage 150 -> 146 GB over eight
      // days is normal variation and must not turn the whole PC "declining".
      if (bad.badSlope >= minimumMaterialSlope &&
          bad.directionAgreement >= minimumBadTrendAgreement &&
          bad.stability >= 0.35) {
        worsening++;
        return;
      }

      // Evaluate the opposite direction using the same reliability and
      // material-change rules.
      final good = _trendStats(
        rows,
        (s) => selector(s)!,
        increasingIsBad: !increasingIsBad,
      );
      if (good.badSlope >= minimumMaterialSlope &&
          good.directionAgreement >= minimumBadTrendAgreement &&
          good.stability >= 0.35) {
        improving++;
      }
    }

    evaluate(
      (s) => s.cpuUsage,
      increasingIsBad: true,
      minimumMaterialSlope: minimumCpuRamOverallTrendPerDay,
    );
    evaluate(
      (s) => s.ramUsage,
      increasingIsBad: true,
      minimumMaterialSlope: minimumCpuRamOverallTrendPerDay,
    );
    evaluate(
      (s) => s.storageFreeGb,
      increasingIsBad: false,
      minimumMaterialSlope: minimumStorageOverallTrendGbPerDay,
    );

    if (worsening >= 2) return 1;
    if (improving >= 2) return -1;
    return 0;
  }

  String _overallTrend(
    List<_HealthSnapshot> history,
    double riskSlope,
    int metricDirection,
  ) {
    // The prediction can be ready from raw history while time bucketing leaves
    // fewer than three independent periods. In that case, avoid claiming a
    // direction and report a stable trend until more time-separated data exists.
    if (history.length < minimumSamples) return 'stable';

    final split = max(1, history.length ~/ 2);
    final older = history.sublist(0, split);
    final newer = history.sublist(split);

    final oldAvg = older.map((s) => s.instantRisk).reduce((a, b) => a + b) /
        older.length;
    final newAvg = newer.isEmpty
        ? oldAvg
        : newer.map((s) => s.instantRisk).reduce((a, b) => a + b) /
            newer.length;

    if (newAvg - oldAvg >= 12 || riskSlope >= 3 || metricDirection > 0) {
      return 'declining';
    }
    if (oldAvg - newAvg >= 12 || riskSlope <= -3 || metricDirection < 0) {
      return 'improving';
    }
    return 'stable';
  }

  int _predictionConfidence(
    List<_HealthSnapshot> history, {
    DateTime? resetBoundary,
  }) {
    if (history.length < minimumSamples) return 0;

    final representative = _bucketSnapshots(history, recurrenceBucket);
    if (representative.isEmpty) return 0;

    final sampleFactor = min(1.0, representative.length / 8.0);
    final spanHours = representative.length >= 2
        ? representative.last.timestamp
                .difference(representative.first.timestamp)
                .inMinutes /
            60.0
        : 0.0;
    final spanFactor = min(1.0, spanHours / (24.0 * 7.0));

    final coverage = representative
            .map((row) => row.coreCoverage)
            .fold<double>(0.0, (a, b) => a + b) /
        representative.length;

    final numericCoverage = representative
            .map((row) {
              final values = <double?>[
                row.cpuUsage,
                row.ramUsage,
                row.storageFreeGb,
                row.storageTotalGb,
              ];
              return values.where((v) => v != null).length / values.length;
            })
            .fold<double>(0.0, (a, b) => a + b) /
        representative.length;

    final regularity = _samplingRegularity(representative);

    var score = (
      sampleFactor * 35 +
      spanFactor * 25 +
      coverage * 15 +
      numericCoverage * 10 +
      regularity * 15
    ).round();

    // Confidence should not look high when all checks happened in one short
    // testing session, even if there are many rows.
    if (spanHours < 24) score = min(score, 45);
    if (representative.length == 3) score = min(score, 55);
    if (representative.length == 4) score = min(score, 65);

    // After maintenance, old history can explain the previous fault, but a new
    // prediction should not receive high confidence until enough post-service
    // evidence exists.
    if (resetBoundary != null) {
      final postMaintenance = representative
          .where((row) => !row.timestamp.isBefore(resetBoundary))
          .length;
      if (postMaintenance < 3) score = min(score, 45);
      if (postMaintenance == 3) score = min(score, 60);
    }

    return score.clamp(0, 100).toInt();
  }

  double _samplingRegularity(List<_HealthSnapshot> rows) {
    if (rows.length < 3) return 0.5;
    final gaps = <double>[];
    for (var i = 1; i < rows.length; i++) {
      final minutes = rows[i].timestamp.difference(rows[i - 1].timestamp).inMinutes;
      if (minutes > 0) gaps.add(minutes.toDouble());
    }
    if (gaps.length < 2) return 0.5;
    final medianGap = _median(gaps);
    if (medianGap <= 0) return 0.5;
    final mad = _medianAbsoluteDeviation(gaps, medianGap);
    return (1.0 - (mad / (medianGap + 1.0))).clamp(0.0, 1.0).toDouble();
  }

  String _confidenceLevel(int score) {
    if (score >= 70) return 'high';
    if (score >= 40) return 'medium';
    return 'low';
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
    required int confidenceScore,
    required String confidenceLevel,
  }) {
    final quality = sampleCount >= recommendedSamples
        ? 'based on $sampleCount recent checks'
        : 'based on only $sampleCount checks';

    final spanHours = span.inHours;
    final spanText = spanHours >= 24
        ? '${(spanHours / 24).toStringAsFixed(spanHours >= 72 ? 0 : 1)} days'
        : '$spanHours hours';
    final confidence =
        '${confidenceLevel.toUpperCase()} confidence ($confidenceScore/100)';

    if (riskLevel == 'low') {
      return 'The workstation is currently stable. No significant future-risk pattern is detected $quality across $spanText. Predictive risk: $riskScore/100. $confidence.';
    }

    final source = strongest.isEmpty ? 'recent health history' : strongest.join(' and ');
    final timing = hasTimedForecast
        ? window
        : 'A reliable failure date cannot be calculated from the available data.';

    if (riskLevel == 'moderate') {
      return 'The workstation has a moderate future-risk score of $riskScore/100. $source shows a recurring or worsening pattern, $quality across $spanText. $timing $confidence.';
    }
    if (riskLevel == 'high') {
      return 'The workstation has a high future-risk score of $riskScore/100. $source shows a strong recurring or worsening pattern, $quality across $spanText. $timing $confidence.';
    }
    return 'The workstation has a critical predictive risk score of $riskScore/100. $source shows the strongest recurring or worsening pattern, $quality across $spanText. $timing $confidence.';
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

class _RiskAdjustment {
  final int adjustment;
  final String? message;

  const _RiskAdjustment({
    this.adjustment = 0,
    this.message,
  });
}

class _MaintenanceContext {
  final DateTime timestamp;
  final String condition;

  const _MaintenanceContext({
    required this.timestamp,
    required this.condition,
  });
}

class _RepairContext {
  final DateTime timestamp;
  final String component;
  final String issue;

  const _RepairContext({
    required this.timestamp,
    required this.component,
    required this.issue,
  });
}

class _TrendStats {
  final double slope;
  final double badSlope;
  final double directionAgreement;
  final double stability;
  final bool accelerating;

  const _TrendStats({
    this.slope = 0,
    this.badSlope = 0,
    this.directionAgreement = 0,
    this.stability = 0,
    this.accelerating = false,
  });
}

class _HealthSnapshot {
  final String id;
  final String workstationId;
  final String roomName;
  final String pcId;
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
    this.workstationId = '',
    this.roomName = '',
    this.pcId = '',
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

  double get coreCoverage {
    final values = <bool?>[
      cpuOk,
      ramOk,
      diskOk,
      storageHealthOk,
      storageCapacityOk,
      networkOk,
      keyboardOk,
      mouseOk,
      monitorOk,
    ];
    return values.where((v) => v != null).length / values.length;
  }

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
    final recordId = record.id.trim();
    final id = record.lastCheck != null
        ? '${recordId.isEmpty ? 'health' : recordId}|${timestamp.toIso8601String()}'
        : recordId.isNotEmpty
            ? recordId
            : '${record.status}|$detailsSignature';

    return _HealthSnapshot(
      id: id,
      workstationId: record.workstationId.trim(),
      roomName: record.roomName.trim(),
      pcId: record.pcId.trim(),
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
      workstationId: (json['workstationId'] ?? '').toString(),
      roomName: (json['roomName'] ?? '').toString(),
      pcId: (json['pcId'] ?? '').toString(),
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
        'workstationId': workstationId,
        'roomName': roomName,
        'pcId': pcId,
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

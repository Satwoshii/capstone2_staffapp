import 'package:flutter_test/flutter_test.dart';

import '../lib/models/pc_health_record.dart';
import '../lib/services/pc_health_prediction_service.dart';

void main() {
  final predictor = PcHealthPredictionService.instance;

  setUp(() async {
    await predictor.clearHistory();
  });

  group('Syswatch PC Health Prediction Algorithm v3', () {
    test('1. Collects history until at least 3 checks exist', () async {
      final now = DateTime(2026, 9, 22, 12);
      final records = <PcHealthRecord>[
        _record(
          id: 'collect-1',
          time: now.subtract(const Duration(days: 2)),
          cpuUsage: 35,
          ramUsage: 40,
          storageFreeGb: 120,
        ),
        _record(
          id: 'collect-2',
          time: now.subtract(const Duration(days: 1)),
          cpuUsage: 38,
          ramUsage: 43,
          storageFreeGb: 118,
        ),
      ];

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);
      _printResult('COLLECTING TEST', result);

      expect(result.ready, isFalse);
      expect(result.historyCount, 2);
      expect(result.riskLevel, 'collecting');
    });

    test('2. Healthy stable PC remains low risk with high confidence', () async {
      final now = DateTime(2026, 9, 22, 12);
      final records = <PcHealthRecord>[
        _record(id: 'stable-1', time: now.subtract(const Duration(days: 8)), cpuUsage: 30, ramUsage: 40, storageFreeGb: 150),
        _record(id: 'stable-2', time: now.subtract(const Duration(days: 6)), cpuUsage: 32, ramUsage: 42, storageFreeGb: 149),
        _record(id: 'stable-3', time: now.subtract(const Duration(days: 4)), cpuUsage: 29, ramUsage: 41, storageFreeGb: 148),
        _record(id: 'stable-4', time: now.subtract(const Duration(days: 2)), cpuUsage: 33, ramUsage: 43, storageFreeGb: 147),
        _record(id: 'stable-5', time: now, cpuUsage: 31, ramUsage: 42, storageFreeGb: 146),
      ];

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);
      _printResult('HEALTHY / STABLE TEST', result);

      expect(result.ready, isTrue);
      expect(result.riskLevel, 'low');
      expect(result.trend, 'stable');
      expect(result.riskScore, lessThan(25));
      expect(result.confidenceScore, greaterThanOrEqualTo(70));
      expect(result.predictedProblemWindow, 'No immediate problem predicted');
    });

    test('3. Worsening PC produces declining elevated risk and timed forecasts', () async {
      final now = DateTime(2026, 9, 22, 12);
      final records = <PcHealthRecord>[
        _record(id: 'decline-1', time: now.subtract(const Duration(days: 8)), cpuUsage: 35, ramUsage: 40, storageFreeGb: 120),
        _record(id: 'decline-2', time: now.subtract(const Duration(days: 6)), cpuUsage: 48, ramUsage: 52, storageFreeGb: 95),
        _record(
          id: 'decline-3',
          time: now.subtract(const Duration(days: 4)),
          cpuUsage: 62,
          ramUsage: 67,
          storageFreeGb: 70,
          networkOk: false,
          status: 'minor',
        ),
        _record(
          id: 'decline-4',
          time: now.subtract(const Duration(days: 2)),
          cpuUsage: 76,
          ramUsage: 81,
          storageFreeGb: 45,
          diskOk: false,
          networkOk: false,
          mouseOk: false,
          status: 'high',
        ),
        _record(
          id: 'decline-5',
          time: now,
          cpuUsage: 89,
          ramUsage: 91,
          storageFreeGb: 28,
          diskOk: false,
          storageHealthOk: false,
          networkOk: false,
          mouseOk: false,
          status: 'critical',
        ),
      ];

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);
      _printResult('DECLINING / HIGH-RISK TEST', result);

      expect(result.ready, isTrue);
      expect(result.trend, 'declining');
      expect(result.riskScore, greaterThanOrEqualTo(25));
      expect(['moderate', 'high', 'critical'], contains(result.riskLevel));
      expect(
        result.components.any(
          (component) =>
              component.estimatedDays != null &&
              component.estimatedDays! >= 0 &&
              component.estimatedDays! <= 90,
        ),
        isTrue,
      );
    });

    test('4. Recovering PC produces improving trend and reduced risk', () async {
      final now = DateTime(2026, 9, 22, 12);
      final records = <PcHealthRecord>[
        _record(
          id: 'recover-1',
          time: now.subtract(const Duration(days: 8)),
          cpuUsage: 92,
          ramUsage: 94,
          storageFreeGb: 20,
          diskOk: false,
          storageHealthOk: false,
          storageCapacityOk: false,
          networkOk: false,
          mouseOk: false,
          status: 'critical',
        ),
        _record(
          id: 'recover-2',
          time: now.subtract(const Duration(days: 6)),
          cpuUsage: 82,
          ramUsage: 84,
          storageFreeGb: 38,
          diskOk: false,
          networkOk: false,
          mouseOk: false,
          status: 'high',
        ),
        _record(id: 'recover-3', time: now.subtract(const Duration(days: 4)), cpuUsage: 68, ramUsage: 71, storageFreeGb: 60, status: 'minor'),
        _record(id: 'recover-4', time: now.subtract(const Duration(days: 2)), cpuUsage: 50, ramUsage: 55, storageFreeGb: 90),
        _record(id: 'recover-5', time: now, cpuUsage: 35, ramUsage: 42, storageFreeGb: 120),
      ];

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);
      _printResult('RECOVERY TEST', result);

      expect(result.ready, isTrue);
      expect(result.trend, 'improving');
      expect(result.riskScore, lessThan(25));
      expect(result.riskLevel, 'low');
    });

    test('5. One CPU spike does not create a false future-failure forecast', () async {
      final now = DateTime(2026, 9, 22, 12);
      final records = <PcHealthRecord>[
        _record(id: 'spike-1', time: now.subtract(const Duration(days: 8)), cpuUsage: 30, ramUsage: 40, storageFreeGb: 150),
        _record(id: 'spike-2', time: now.subtract(const Duration(days: 6)), cpuUsage: 31, ramUsage: 41, storageFreeGb: 149),
        _record(id: 'spike-3', time: now.subtract(const Duration(days: 4)), cpuUsage: 95, ramUsage: 42, storageFreeGb: 148),
        _record(id: 'spike-4', time: now.subtract(const Duration(days: 2)), cpuUsage: 32, ramUsage: 41, storageFreeGb: 147),
        _record(id: 'spike-5', time: now, cpuUsage: 33, ramUsage: 42, storageFreeGb: 146),
      ];

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);
      _printResult('OUTLIER / SPIKE TEST', result);

      final cpu = result.components.firstWhere((c) => c.component == 'CPU');
      expect(result.riskLevel, 'low');
      expect(result.trend, 'stable');
      expect(cpu.estimatedDays, isNull);
      expect(cpu.riskScore, lessThan(25));
    });

    test('6. Rapid polling during one network outage is not treated as many failures', () async {
      final start = DateTime(2026, 9, 22, 12, 0);
      final records = List<PcHealthRecord>.generate(12, (index) {
        return _record(
          id: 'poll-$index',
          time: start.add(Duration(minutes: index * 5)),
          cpuUsage: 30,
          ramUsage: 40,
          storageFreeGb: 150,
          networkOk: false,
          status: 'minor',
        );
      });

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);
      _printResult('RAPID POLLING / SINGLE OUTAGE TEST', result);

      final network = result.components.firstWhere((c) => c.component == 'Ethernet/LAN');
      expect(result.ready, isTrue);
      expect(network.riskScore, lessThan(25));
      expect(result.riskLevel, 'low');
      expect(result.confidenceLevel, 'low');
    });
  });
}

PcHealthRecord _record({
  required String id,
  required DateTime time,
  required double cpuUsage,
  required double ramUsage,
  required double storageFreeGb,
  String status = 'healthy',
  bool cpuOk = true,
  bool ramOk = true,
  bool diskOk = true,
  bool storageHealthOk = true,
  bool storageCapacityOk = true,
  bool networkOk = true,
  bool keyboardOk = true,
  bool mouseOk = true,
  bool monitorOk = true,
}) {
  return PcHealthRecord(
    id: id,
    workstationId: 'TEST-PC-001',
    roomName: '706',
    pcId: 'TEST-PC-001',
    status: status,
    lastCheck: time,
    lastDisplayName: 'Algorithm Test',
    details: <String, dynamic>{
      'cpuOk': cpuOk,
      'ramOk': ramOk,
      'diskOk': diskOk,
      'storageHealthOk': storageHealthOk,
      'storageCapacityOk': storageCapacityOk,
      'networkOk': networkOk,
      'keyboardOk': keyboardOk,
      'mouseOk': mouseOk,
      'monitorOk': monitorOk,
      'webcamOk': true,
      'printerOk': true,
      'headsetOk': true,
      'cpuUsage': cpuUsage,
      'ramUsage': ramUsage,
      'storageFreeGb': storageFreeGb,
      'storageTotalGb': 256.0,
      'severity': status,
    },
  );
}

void _printResult(String title, dynamic result) {
  print('');
  print('============================================================');
  print(title);
  print('============================================================');
  print('Ready                 : ${result.ready}');
  print('History count         : ${result.historyCount}');
  print('Risk score            : ${result.riskScore}/100');
  print('Risk level            : ${result.riskLevel}');
  print('Trend                 : ${result.trend}');
  print('Confidence            : ${result.confidenceLevel} ${result.confidenceScore}/100');
  print('Predicted problem     : ${result.predictedProblemWindow}');
  print('');
  print('SUMMARY');
  print(result.summary);

  if (result.reasons.isNotEmpty) {
    print('');
    print('MAIN REASONS');
    for (final reason in result.reasons) {
      print(' - $reason');
    }
  }

  if (result.components.isNotEmpty) {
    print('');
    print('COMPONENT PREDICTIONS');
    for (final component in result.components) {
      print('');
      print(component.component);
      print('   Risk level : ${component.riskLevel}');
      print('   Risk score : ${component.riskScore}/100');
      if (component.estimatedDays != null && component.estimatedDays! <= 90) {
        print('   Est. days  : ${component.estimatedDays!.toStringAsFixed(2)}');
      }
      print('   Message    : ${component.message}');
    }
  }

  print('============================================================');
}

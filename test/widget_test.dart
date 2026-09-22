import 'package:flutter_test/flutter_test.dart';

import '../lib/models/pc_health_record.dart';
import '../lib/services/pc_health_prediction_service.dart';

void main() {
  final predictor = PcHealthPredictionService.instance;

  setUp(() async {
    // Every test starts with an empty prediction history.
    await predictor.clearHistory();
  });

  group('Syswatch PC Health Prediction Algorithm', () {
    test('1. Collects history until at least 3 checks exist', () async {
      final now = DateTime(2026, 9, 22, 12, 0);

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

    test('2. Healthy stable PC produces low/stable prediction', () async {
      final now = DateTime(2026, 9, 22, 12, 0);

      final records = <PcHealthRecord>[
        _record(
          id: 'stable-1',
          time: now.subtract(const Duration(days: 8)),
          cpuUsage: 30,
          ramUsage: 40,
          storageFreeGb: 150,
        ),
        _record(
          id: 'stable-2',
          time: now.subtract(const Duration(days: 6)),
          cpuUsage: 32,
          ramUsage: 42,
          storageFreeGb: 149,
        ),
        _record(
          id: 'stable-3',
          time: now.subtract(const Duration(days: 4)),
          cpuUsage: 29,
          ramUsage: 41,
          storageFreeGb: 148,
        ),
        _record(
          id: 'stable-4',
          time: now.subtract(const Duration(days: 2)),
          cpuUsage: 33,
          ramUsage: 43,
          storageFreeGb: 147,
        ),
        _record(
          id: 'stable-5',
          time: now,
          cpuUsage: 31,
          ramUsage: 42,
          storageFreeGb: 146,
        ),
      ];

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);

      _printResult('HEALTHY / STABLE TEST', result);

      expect(result.ready, isTrue);
      expect(result.historyCount, greaterThanOrEqualTo(3));
      expect(result.riskLevel, 'low');
      expect(result.trend, 'stable');
    });

    test('3. Worsening PC produces declining and elevated risk', () async {
      final now = DateTime(2026, 9, 22, 12, 0);

      final records = <PcHealthRecord>[
        _record(
          id: 'decline-1',
          time: now.subtract(const Duration(days: 8)),
          cpuUsage: 35,
          ramUsage: 40,
          storageFreeGb: 120,
        ),
        _record(
          id: 'decline-2',
          time: now.subtract(const Duration(days: 6)),
          cpuUsage: 48,
          ramUsage: 52,
          storageFreeGb: 95,
        ),
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
      expect(
        ['moderate', 'high', 'critical'],
        contains(result.riskLevel),
      );

      // At least CPU/RAM/storage should have a numerical threshold forecast.
      final timedPredictions = result.components
          .where((component) => component.estimatedDays != null)
          .toList();

      expect(timedPredictions, isNotEmpty);
    });

    test('4. Recovering PC produces improving trend', () async {
      final now = DateTime(2026, 9, 22, 12, 0);

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
        _record(
          id: 'recover-3',
          time: now.subtract(const Duration(days: 4)),
          cpuUsage: 68,
          ramUsage: 71,
          storageFreeGb: 60,
          status: 'minor',
        ),
        _record(
          id: 'recover-4',
          time: now.subtract(const Duration(days: 2)),
          cpuUsage: 50,
          ramUsage: 55,
          storageFreeGb: 90,
        ),
        _record(
          id: 'recover-5',
          time: now,
          cpuUsage: 35,
          ramUsage: 42,
          storageFreeGb: 120,
        ),
      ];

      await predictor.ingest(records);
      final result = predictor.predictFor(records.last);

      _printResult('RECOVERY TEST', result);

      expect(result.ready, isTrue);
      expect(result.trend, 'improving');
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
      // Current health flags
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

      // Numeric values used by the predictive trend algorithm
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
      print('${component.component}');
      print('   Risk level : ${component.riskLevel}');
      print('   Risk score : ${component.riskScore}/100');
      if (component.estimatedDays != null) {
        print(
          '   Est. days  : '
          '${component.estimatedDays!.toStringAsFixed(2)}',
        );
      }
      print('   Message    : ${component.message}');
    }
  }

  print('============================================================');
}

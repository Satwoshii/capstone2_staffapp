import 'package:flutter_test/flutter_test.dart';

import '../lib/models/pc_health_record.dart';
import '../lib/services/pc_health_prediction_service.dart';

void main() {
  final predictor = PcHealthPredictionService.instance;

  setUp(() async {
    // Start every test with empty prediction history.
    await predictor.clearHistory();
  });

  group('Syswatch PC Health Prediction Algorithm', () {
    // ============================================================
    // TEST 1
    // Not enough history
    // ============================================================

    test(
      '1. Collects history until at least 3 checks exist',
          () async {
        final now = DateTime(2026, 9, 22, 12, 0);

        final records = <PcHealthRecord>[
          _record(
            id: 'collect-1',
            time: now.subtract(
              const Duration(days: 2),
            ),
            cpuUsage: 35,
            ramUsage: 40,
            storageFreeGb: 120,
          ),
          _record(
            id: 'collect-2',
            time: now.subtract(
              const Duration(days: 1),
            ),
            cpuUsage: 38,
            ramUsage: 43,
            storageFreeGb: 118,
          ),
        ];

        await predictor.ingest(records);

        final result =
        predictor.predictFor(records.last);

        _printResult(
          'COLLECTING TEST',
          result,
        );

        expect(
          result.ready,
          isFalse,
        );

        expect(
          result.historyCount,
          2,
        );

        expect(
          result.riskLevel,
          'collecting',
        );
      },
    );

    // ============================================================
    // TEST 2
    // Healthy and stable PC
    // ============================================================

    test(
      '2. Healthy stable PC produces low/stable prediction',
          () async {
        final now = DateTime(2026, 9, 22, 12, 0);

        final records = <PcHealthRecord>[
          _record(
            id: 'stable-1',
            time: now.subtract(
              const Duration(days: 8),
            ),
            cpuUsage: 30,
            ramUsage: 40,
            storageFreeGb: 150,
          ),
          _record(
            id: 'stable-2',
            time: now.subtract(
              const Duration(days: 6),
            ),
            cpuUsage: 32,
            ramUsage: 42,
            storageFreeGb: 149,
          ),
          _record(
            id: 'stable-3',
            time: now.subtract(
              const Duration(days: 4),
            ),
            cpuUsage: 29,
            ramUsage: 41,
            storageFreeGb: 148,
          ),
          _record(
            id: 'stable-4',
            time: now.subtract(
              const Duration(days: 2),
            ),
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

        final result =
        predictor.predictFor(records.last);

        _printResult(
          'HEALTHY / STABLE TEST',
          result,
        );

        expect(
          result.ready,
          isTrue,
        );

        expect(
          result.historyCount,
          greaterThanOrEqualTo(3),
        );

        expect(
          result.riskLevel,
          'low',
        );

        expect(
          result.trend,
          'stable',
        );

        expect(
          result.riskScore,
          lessThan(25),
        );
      },
    );

    // ============================================================
    // TEST 3
    // Worsening PC
    // ============================================================

    test(
      '3. Worsening PC produces declining and elevated risk',
          () async {
        final now = DateTime(2026, 9, 22, 12, 0);

        final records = <PcHealthRecord>[
          // Healthy
          _record(
            id: 'decline-1',
            time: now.subtract(
              const Duration(days: 8),
            ),
            cpuUsage: 35,
            ramUsage: 40,
            storageFreeGb: 120,
          ),

          // Starting to increase
          _record(
            id: 'decline-2',
            time: now.subtract(
              const Duration(days: 6),
            ),
            cpuUsage: 48,
            ramUsage: 52,
            storageFreeGb: 95,
          ),

          // Network problem begins
          _record(
            id: 'decline-3',
            time: now.subtract(
              const Duration(days: 4),
            ),
            cpuUsage: 62,
            ramUsage: 67,
            storageFreeGb: 70,
            networkOk: false,
            status: 'minor',
          ),

          // More components begin failing
          _record(
            id: 'decline-4',
            time: now.subtract(
              const Duration(days: 2),
            ),
            cpuUsage: 76,
            ramUsage: 81,
            storageFreeGb: 45,
            diskOk: false,
            networkOk: false,
            mouseOk: false,
            status: 'high',
          ),

          // Current / latest health
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

        final result =
        predictor.predictFor(records.last);

        _printResult(
          'DECLINING / HIGH-RISK TEST',
          result,
        );

        expect(
          result.ready,
          isTrue,
        );

        expect(
          result.trend,
          'declining',
        );

        expect(
          result.riskScore,
          greaterThanOrEqualTo(25),
        );

        expect(
          [
            'moderate',
            'high',
            'critical',
          ],
          contains(result.riskLevel),
        );

        // CPU/RAM/storage should have at least
        // one meaningful near-term forecast.
        final timedPredictions =
        result.components.where(
              (component) {
            final days =
                component.estimatedDays;

            return days != null &&
                days >= 0 &&
                days <= 90;
          },
        ).toList();

        expect(
          timedPredictions,
          isNotEmpty,
        );
      },
    );

    // ============================================================
    // TEST 4
    // Recovering PC
    // ============================================================

    test(
      '4. Recovering PC produces improving trend',
          () async {
        final now = DateTime(2026, 9, 22, 12, 0);

        final records = <PcHealthRecord>[
          // Initially critical
          _record(
            id: 'recover-1',
            time: now.subtract(
              const Duration(days: 8),
            ),
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

          // Beginning to recover
          _record(
            id: 'recover-2',
            time: now.subtract(
              const Duration(days: 6),
            ),
            cpuUsage: 82,
            ramUsage: 84,
            storageFreeGb: 38,
            diskOk: false,
            networkOk: false,
            mouseOk: false,
            status: 'high',
          ),

          // Significant improvement
          _record(
            id: 'recover-3',
            time: now.subtract(
              const Duration(days: 4),
            ),
            cpuUsage: 68,
            ramUsage: 71,
            storageFreeGb: 60,
            status: 'minor',
          ),

          // Almost normal
          _record(
            id: 'recover-4',
            time: now.subtract(
              const Duration(days: 2),
            ),
            cpuUsage: 50,
            ramUsage: 55,
            storageFreeGb: 90,
          ),

          // Healthy
          _record(
            id: 'recover-5',
            time: now,
            cpuUsage: 35,
            ramUsage: 42,
            storageFreeGb: 120,
          ),
        ];

        await predictor.ingest(records);

        final result =
        predictor.predictFor(records.last);

        _printResult(
          'RECOVERY TEST',
          result,
        );

        expect(
          result.ready,
          isTrue,
        );

        expect(
          result.trend,
          'improving',
        );

        expect(
          result.riskLevel,
          'low',
        );
      },
    );
  });
}

/// ============================================================
/// Creates one fake PC-health record.
///
/// All test records use the same workstation so the predictor
/// understands that they belong to one PC.
/// ============================================================

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
      // ========================================================
      // Boolean health checks
      // ========================================================

      'cpuOk': cpuOk,

      'ramOk': ramOk,

      'diskOk': diskOk,

      'storageHealthOk':
      storageHealthOk,

      'storageCapacityOk':
      storageCapacityOk,

      'networkOk': networkOk,

      'keyboardOk': keyboardOk,

      'mouseOk': mouseOk,

      'monitorOk': monitorOk,

      'webcamOk': true,

      'printerOk': true,

      'headsetOk': true,

      // ========================================================
      // Numerical data used for forecasting
      // ========================================================

      'cpuUsage': cpuUsage,

      'ramUsage': ramUsage,

      'storageFreeGb':
      storageFreeGb,

      'storageTotalGb': 256.0,

      // Current severity
      'severity': status,
    },
  );
}

/// ============================================================
/// Pretty console output
/// ============================================================

void _printResult(
    String title,
    dynamic result,
    ) {
  print('');

  print(
    '============================================================',
  );

  print(title);

  print(
    '============================================================',
  );

  print(
    'Ready                 : '
        '${result.ready}',
  );

  print(
    'History count         : '
        '${result.historyCount}',
  );

  print(
    'Risk score            : '
        '${result.riskScore}/100',
  );

  print(
    'Risk level            : '
        '${result.riskLevel}',
  );

  print(
    'Trend                 : '
        '${result.trend}',
  );

  // Do not display "Beyond 2 months" for a healthy PC.
  final problemWindow =
  _displayProblemWindow(result);

  print(
    'Predicted problem     : '
        '$problemWindow',
  );

  print('');

  print('SUMMARY');

  print(result.summary);

  // ==========================================================
  // Main reasons
  // ==========================================================

  if (result.reasons.isNotEmpty) {
    print('');

    print('MAIN REASONS');

    for (final reason
    in result.reasons) {
      print(
        ' - $reason',
      );
    }
  }

  // ==========================================================
  // Component results
  // ==========================================================

  if (result.components.isNotEmpty) {
    print('');

    print(
      'COMPONENT PREDICTIONS',
    );

    for (final component
    in result.components) {
      print('');

      print(
        '${component.component}',
      );

      print(
        '   Risk level : '
            '${component.riskLevel}',
      );

      print(
        '   Risk score : '
            '${component.riskScore}/100',
      );

      final days =
          component.estimatedDays;

      // ======================================================
      // Only show useful near-term estimates.
      //
      // Example:
      //   2 days   -> show
      //   30 days  -> show
      //   80 days  -> show
      //   192 days -> hide
      //   314 days -> hide
      // ======================================================

      if (days != null &&
          days >= 0 &&
          days <= 90) {
        print(
          '   Est. days  : '
              '${days.toStringAsFixed(2)}',
        );
      }

      print(
        '   Message    : '
            '${component.message}',
      );
    }
  }

  print(
    '============================================================',
  );
}

/// ============================================================
/// Improves the displayed prediction window.
///
/// The predictor may mathematically calculate a threshold that is
/// hundreds of days away. That is not useful as a maintenance
/// warning.
///
/// We only present near-term forecasts up to 90 days.
/// ============================================================

String _displayProblemWindow(
    dynamic result,
    ) {
  if (!result.ready) {
    return result
        .predictedProblemWindow;
  }

  // A healthy / stable PC should not display
  // "Beyond 2 months".
  if (result.riskLevel == 'low' &&
      result.trend == 'stable') {
    return 'No immediate problem predicted';
  }

  // Check whether there is at least one useful
  // numerical forecast within 90 days.
  final usefulForecast =
  result.components.any(
        (component) {
      final days =
          component.estimatedDays;

      return days != null &&
          days >= 0 &&
          days <= 90;
    },
  );

  if (!usefulForecast) {
    if (result.riskLevel ==
        'high' ||
        result.riskLevel ==
            'critical') {
      return 'Elevated risk — no reliable date estimate';
    }

    if (result.riskLevel ==
        'moderate') {
      return 'Monitor trend — no reliable date estimate';
    }

    return 'No immediate problem predicted';
  }

  return result
      .predictedProblemWindow;
}
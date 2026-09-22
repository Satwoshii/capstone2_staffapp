class PcComponentPrediction {
  final String component;
  final int riskScore;
  final String riskLevel;
  final double? estimatedDays;
  final String message;

  const PcComponentPrediction({
    required this.component,
    required this.riskScore,
    required this.riskLevel,
    required this.message,
    this.estimatedDays,
  });
}

class PcHealthPrediction {
  final bool ready;
  final int historyCount;
  final int riskScore;
  final String riskLevel;
  final String trend;
  final String predictedProblemWindow;
  final String summary;
  final List<String> reasons;
  final List<PcComponentPrediction> components;

  /// Confidence describes how much useful history is available for the
  /// prediction. It is NOT the same thing as risk.
  final int confidenceScore;
  final String confidenceLevel;

  const PcHealthPrediction({
    required this.ready,
    required this.historyCount,
    required this.riskScore,
    required this.riskLevel,
    required this.trend,
    required this.predictedProblemWindow,
    required this.summary,
    required this.reasons,
    required this.components,
    this.confidenceScore = 0,
    this.confidenceLevel = 'low',
  });

  factory PcHealthPrediction.collecting(int count, {int requiredCount = 3}) {
    return PcHealthPrediction(
      ready: false,
      historyCount: count,
      riskScore: 0,
      riskLevel: 'collecting',
      trend: 'collecting',
      predictedProblemWindow: 'Collecting health history',
      summary:
          'Syswatch needs at least $requiredCount distinct health checks before it can calculate a future-risk trend. Current history: $count/$requiredCount.',
      reasons: const [],
      components: const [],
      confidenceScore: 0,
      confidenceLevel: 'collecting',
    );
  }
}

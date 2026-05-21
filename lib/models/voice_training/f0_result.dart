/// 单次 F0（基频）测量结果
class F0Result {
  /// 频率值（Hz）
  final double pitch;

  /// 检测概率（0.0 ~ 1.0）
  final double probability;

  /// 是否检测到音高
  final bool pitched;

  /// 测量时间戳（与测试开始的时间差，毫秒）
  final double timestampMs;

  const F0Result({
    required this.pitch,
    required this.probability,
    required this.pitched,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => {
        'pitch': pitch,
        'probability': probability,
        'pitched': pitched,
        'timestampMs': timestampMs,
      };

  factory F0Result.fromJson(Map<String, dynamic> json) => F0Result(
        pitch: (json['pitch'] as num).toDouble(),
        probability: (json['probability'] as num).toDouble(),
        pitched: json['pitched'] as bool,
        timestampMs: (json['timestampMs'] as num).toDouble(),
      );
}

/// 快速基频测试汇总结果
class QuickF0TestResult {
  /// 平均基频（Hz）
  final double averageF0;

  /// 中位基频（Hz）
  final double medianF0;

  /// 最低基频（Hz）
  final double minF0;

  /// 最高基频（Hz）
  final double maxF0;

  /// 测试持续时间（毫秒）
  final double durationMs;

  /// 所有有效 F0 数据点
  final List<F0Result> dataPoints;

  /// 测试时间
  final DateTime testTime;

  const QuickF0TestResult({
    required this.averageF0,
    required this.medianF0,
    required this.minF0,
    required this.maxF0,
    required this.durationMs,
    required this.dataPoints,
    required this.testTime,
  });

  Map<String, dynamic> toJson() => {
        'averageF0': averageF0,
        'medianF0': medianF0,
        'minF0': minF0,
        'maxF0': maxF0,
        'durationMs': durationMs,
        'dataPoints': dataPoints.map((e) => e.toJson()).toList(),
        'testTime': testTime.toIso8601String(),
      };

  factory QuickF0TestResult.fromJson(Map<String, dynamic> json) =>
      QuickF0TestResult(
        averageF0: (json['averageF0'] as num).toDouble(),
        medianF0: (json['medianF0'] as num).toDouble(),
        minF0: (json['minF0'] as num).toDouble(),
        maxF0: (json['maxF0'] as num).toDouble(),
        durationMs: (json['durationMs'] as num).toDouble(),
        dataPoints: (json['dataPoints'] as List)
            .map((e) => F0Result.fromJson(e as Map<String, dynamic>))
            .toList(),
        testTime: DateTime.parse(json['testTime'] as String),
      );
}

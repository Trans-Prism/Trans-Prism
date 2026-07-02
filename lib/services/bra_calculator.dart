/// 罩杯计算结果（三地尺码）
class BraResult {
  /// 底围尺寸（取整后的厘米值，5 的倍数）
  final int bandSize;

  /// 罩杯字母（CN 标准，AA / A / B / C / D / E）
  final String cupLetter;

  /// 中国尺码，如 "75B"
  String get fullSize => '$bandSize$cupLetter';

  final String cnSize;

  /// 俗称/英美尺码，如 "34B"
  final String usSize;

  /// 欧洲尺码，如 "75A"（底围同 CN，罩杯 2cm 步进）
  final String euSize;

  /// 胸围差（上胸围均值 - 下胸围均值，cm）
  final double difference;

  /// 下胸围均值（cm，取整前）
  final double underbustAvg;

  /// 上胸围均值（cm）
  final double overbustAvg;

  /// 是否需要穿内衣（diff < 5 时不需要）
  final bool needsBra;

  /// 友好提示文本
  final String? message;

  const BraResult({
    required this.bandSize,
    required this.cupLetter,
    required this.cnSize,
    required this.usSize,
    required this.euSize,
    required this.difference,
    required this.underbustAvg,
    required this.overbustAvg,
    required this.needsBra,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'bandSize': bandSize,
        'cupLetter': cupLetter,
        'cnSize': cnSize,
        'usSize': usSize,
        'euSize': euSize,
        'fullSize': fullSize,
        'difference': difference,
        'underbustAvg': underbustAvg,
        'overbustAvg': overbustAvg,
        'needsBra': needsBra,
        'message': message,
      };

  factory BraResult.fromJson(Map<String, dynamic> json) => BraResult(
        bandSize: json['bandSize'] as int,
        cupLetter: json['cupLetter'] as String,
        cnSize: (json['cnSize'] as String?) ?? '',
        usSize: (json['usSize'] as String?) ?? '',
        euSize: (json['euSize'] as String?) ?? '',
        difference: (json['difference'] as num).toDouble(),
        underbustAvg: (json['underbustAvg'] as num).toDouble(),
        overbustAvg: (json['overbustAvg'] as num).toDouble(),
        needsBra: json['needsBra'] as bool,
        message: json['message'] as String?,
      );
}

/// 罩杯计算器 — 无状态工具类
///
/// 算法来源：[MtF-wiki](https://github.com/project-trans/MtF-wiki)
/// 遵循中国大陆事实标准：
/// - 胸围差 10cm = A 罩杯，每 ±2.5cm 递进/递减一个罩杯
/// - 底围取两次测量均值，向上取整至最接近的 5 的倍数
///
/// 额外输出：
/// - **US/UK 俗称**：罩杯同 CN，底围 `(CN底围/5)*2+4`
/// - **EU 欧洲尺码**：底围同 CN，罩杯采用 2cm 步进
///
/// ## 测量方法
/// 1. `underbustRelaxed` — 直立放松，软尺贴合乳房下缘水平绕量
/// 2. `underbustExhaled` — 呼气后同法测量
/// 3. `overbustStanding` — 直立经过乳头水平绕量
/// 4. `overbust45` — 俯身 45 度测量
/// 5. `overbust90` — 鞠躬 90 度测量
class BraCalculator {
  BraCalculator._();

  static const double minValidDifference = 5.0;

  // ── CN 罩杯阈值（2.5cm 步进） ──
  static const double cnAa = 7.5;
  static const double cnA = 10.0;
  static const double cnB = 12.5;
  static const double cnC = 15.0;
  static const double cnD = 17.5;
  static const double cnE = 20.0;

  // ── EU 罩杯阈值（2cm 步进，起始 12） ──
  static const double euAa = 12.0;
  static const double euA = 14.0;
  static const double euB = 16.0;
  static const double euC = 18.0;
  static const double euD = 20.0;
  static const double euE = 22.0;
  static const double euF = 24.0;
  static const double euG = 26.0;

  static const int bandRoundingBase = 5;

  /// 计算三地罩杯尺码
  static BraResult calculate({
    required double underbustRelaxed,
    required double underbustExhaled,
    required double overbustStanding,
    required double overbust45,
    required double overbust90,
  }) {
    final values = [
      underbustRelaxed,
      underbustExhaled,
      overbustStanding,
      overbust45,
      overbust90
    ];
    if (values.any((v) => v < 0)) {
      throw ArgumentError('所有测量值不能为负数');
    }

    final underbustAvg = (underbustRelaxed + underbustExhaled) / 2;
    final overbustAvg = (overbustStanding + overbust45 + overbust90) / 3;
    final difference = overbustAvg - underbustAvg;

    // ── CN 罩杯 ──
    String cnCup;
    String? message;
    bool needsBra = true;

    if (difference < minValidDifference) {
      cnCup = '';
      needsBra = false;
      message = '目前还不太需要穿内衣哦 ✨';
    } else if (difference <= cnAa) {
      cnCup = 'AA';
      message = '可以看看少女背心或加厚款';
    } else if (difference <= cnA) {
      cnCup = 'A';
    } else if (difference <= cnB) {
      cnCup = 'B';
    } else if (difference <= cnC) {
      cnCup = 'C';
    } else if (difference <= cnD) {
      cnCup = 'D';
    } else if (difference <= cnE) {
      cnCup = 'E';
    } else {
      cnCup = 'E+';
      message = '罩杯超出常规预设范围，建议实际试穿确认';
    }

    // ── CN 底围 ──
    final cnBand = (underbustAvg / bandRoundingBase).ceil() * bandRoundingBase;

    // ── US/UK 底围：公式 (CN 底围 / 5) * 2 + 4 ──
    final usBand = (cnBand / 5) * 2 + 4;
    final usSizeString = needsBra ? '${usBand.toInt()}$cnCup' : '';

    // ── EU 罩杯（2cm 步进） ──
    String euCup;
    if (!needsBra) {
      euCup = '';
    } else if (difference < euAa) {
      euCup = 'AA';
    } else if (difference < euA) {
      euCup = 'A';
    } else if (difference < euB) {
      euCup = 'B';
    } else if (difference < euC) {
      euCup = 'C';
    } else if (difference < euD) {
      euCup = 'D';
    } else if (difference < euE) {
      euCup = 'E';
    } else if (difference < euF) {
      euCup = 'F';
    } else if (difference < euG) {
      euCup = 'G';
    } else {
      euCup = 'G+';
    }
    final euSizeString = needsBra ? '$cnBand$euCup' : '';

    return BraResult(
      bandSize: cnBand,
      cupLetter: cnCup,
      cnSize: needsBra ? '$cnBand$cnCup' : '',
      usSize: usSizeString,
      euSize: euSizeString,
      difference: difference,
      underbustAvg: underbustAvg,
      overbustAvg: overbustAvg,
      needsBra: needsBra,
      message: message,
    );
  }
}

import 'dart:convert';

/// 周期单位枚举
enum CycleUnit {
  hours('小时'),
  days('天'),
  weeks('周'),
  months('月');

  final String label;
  const CycleUnit(this.label);

  /// 将英文标识解析为枚举（向后兼容）
  static CycleUnit fromString(String value) {
    switch (value) {
      case '小时':
      case 'hours':
        return CycleUnit.hours;
      case '天':
      case 'days':
        return CycleUnit.days;
      case '周':
      case 'weeks':
        return CycleUnit.weeks;
      case '月':
      case 'months':
        return CycleUnit.months;
      default:
        return CycleUnit.days;
    }
  }

  String get storageValue {
    switch (this) {
      case CycleUnit.hours:
        return 'hours';
      case CycleUnit.days:
        return 'days';
      case CycleUnit.weeks:
        return 'weeks';
      case CycleUnit.months:
        return 'months';
    }
  }
}

class Drug {
  final String id;
  final String name;
  double currentStock;
  final double dosage;

  // ── 新的复合周期字段 ──
  final double cycleValue; // 周期数值（如 1, 7, 28, 3.5）
  final CycleUnit cycleUnit; // 周期单位

  // ── 锚定日期：下次给药时间 ──
  DateTime? nextDoseTime;

  // ── 每日提醒时间（短效药物用） ──
  final List<String> reminderTimes;
  bool reminderEnabled;

  Drug({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.dosage,
    required this.cycleValue,
    required this.cycleUnit,
    this.nextDoseTime,
    required this.reminderTimes,
    this.reminderEnabled = true,
  });

  // ==================== 计算属性 ====================

  /// 将周期转换为「小时」单位的系数
  double get _cycleInHours {
    switch (cycleUnit) {
      case CycleUnit.hours:
        return cycleValue;
      case CycleUnit.days:
        return cycleValue * 24;
      case CycleUnit.weeks:
        return cycleValue * 7 * 24;
      case CycleUnit.months:
        // 按月近似：1 月 ≈ 30 天
        return cycleValue * 30 * 24;
    }
  }

  /// 每天消耗量
  double get dailyBurnRate {
    final hours = _cycleInHours;
    if (hours <= 0) return 0;
    return (24.0 / hours) * dosage;
  }

  /// 安全续航天数
  int get runwayDays {
    if (dailyBurnRate <= 0) return 999;
    return (currentStock / dailyBurnRate).floor();
  }

  /// 库存剩余百分比（以 30 天库存为 100% 基准）
  double get stockPercentage {
    final thirtyDayStock = dailyBurnRate * 30;
    if (thirtyDayStock <= 0) return 1.0;
    return (currentStock / thirtyDayStock).clamp(0.0, 1.0);
  }

  // ==================== 核心操作 ====================

  /// 记录一次服药：扣减库存 + 自动推算下次给药时间
  void recordDose() {
    currentStock = (currentStock - dosage).clamp(0.0, double.infinity);
    _advanceNextDoseTime();
  }

  /// 补仓
  void addStock(double amount) {
    if (amount > 0) {
      currentStock += amount;
    }
  }

  /// 根据周期自动推算下一次给药时间
  void _advanceNextDoseTime() {
    final now = DateTime.now();

    switch (cycleUnit) {
      case CycleUnit.hours:
        nextDoseTime = now.add(Duration(hours: cycleValue.round()));
        break;
      case CycleUnit.days:
        nextDoseTime = now.add(Duration(days: cycleValue.round()));
        break;
      case CycleUnit.weeks:
        // 支持半周：3.5 天 = 0.5 周
        final days = (cycleValue * 7).round();
        nextDoseTime = now.add(Duration(days: days));
        break;
      case CycleUnit.months:
        // 按月：使用 DateTime 的月份加法
        final months = cycleValue.round();
        nextDoseTime = DateTime(
            now.year, now.month + months, now.day, now.hour, now.minute);
        break;
    }
  }

  /// 手动设置下次给药时间
  void setNextDoseTime(DateTime? time) {
    nextDoseTime = time;
  }

  // ==================== UI 辅助 ====================

  /// 格式化周期描述：「每 12 小时」/「每 7 天」/「每 0.5 周」/「每 28 天」
  String get cycleLabel {
    // 如果是整数则去掉小数
    final val = cycleValue == cycleValue.roundToDouble()
        ? cycleValue.toInt().toString()
        : cycleValue.toStringAsFixed(1);
    return '每 $val ${cycleUnit.label}';
  }

  /// 格式化下次给药时间
  String get nextDoseLabel {
    if (nextDoseTime == null) return '未设置';
    final d = nextDoseTime!;
    final now = DateTime.now();
    final diff = d.difference(now);
    if (diff.isNegative) {
      return '已过期';
    }
    if (diff.inDays > 0) {
      return '${diff.inDays} 天后 (${_formatDateTime(d)})';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} 小时后';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes} 分钟后';
    }
    return '即将开始';
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ==================== JSON 序列化 ====================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currentStock': currentStock,
      'dosage': dosage,
      'cycleValue': cycleValue,
      'cycleUnit': cycleUnit.storageValue,
      'nextDoseTime': nextDoseTime?.toIso8601String(),
      'reminderTimes': reminderTimes,
      'reminderEnabled': reminderEnabled,
    };
  }

  factory Drug.fromJson(Map<String, dynamic> json) {
    final nextDoseStr = json['nextDoseTime'] as String?;
    return Drug(
      id: json['id'] as String,
      name: json['name'] as String,
      currentStock: (json['currentStock'] as num).toDouble(),
      dosage: (json['dosage'] as num).toDouble(),
      cycleValue: (json['cycleValue'] as num?)?.toDouble() ?? 24,
      cycleUnit: CycleUnit.fromString(json['cycleUnit'] as String? ?? 'hours'),
      nextDoseTime: nextDoseStr != null ? DateTime.parse(nextDoseStr) : null,
      reminderTimes: List<String>.from(json['reminderTimes'] as List? ?? []),
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
    );
  }

  static List<Drug> listFromJson(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => Drug.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Drug> drugs) {
    return jsonEncode(drugs.map((d) => d.toJson()).toList());
  }

  Drug copyWith({
    String? id,
    String? name,
    double? currentStock,
    double? dosage,
    double? cycleValue,
    CycleUnit? cycleUnit,
    DateTime? nextDoseTime,
    List<String>? reminderTimes,
    bool? reminderEnabled,
  }) {
    return Drug(
      id: id ?? this.id,
      name: name ?? this.name,
      currentStock: currentStock ?? this.currentStock,
      dosage: dosage ?? this.dosage,
      cycleValue: cycleValue ?? this.cycleValue,
      cycleUnit: cycleUnit ?? this.cycleUnit,
      nextDoseTime: nextDoseTime ?? this.nextDoseTime,
      reminderTimes: reminderTimes ?? List<String>.from(this.reminderTimes),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }
}

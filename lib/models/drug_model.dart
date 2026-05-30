import 'dart:convert';
import 'package:flutter/foundation.dart';

// =============================================================================
// 间隔单位枚举（替代旧的 CycleUnit）
// =============================================================================
enum IntervalUnit {
  hours('小时'),
  days('天'),
  weeks('周'),
  months('月');

  final String label;
  const IntervalUnit(this.label);

  static IntervalUnit fromString(String value) {
    switch (value) {
      case '小时':
      case 'hours':
        return IntervalUnit.hours;
      case '天':
      case 'days':
        return IntervalUnit.days;
      case '周':
      case 'weeks':
        return IntervalUnit.weeks;
      case '月':
      case 'months':
        return IntervalUnit.months;
      default:
        return IntervalUnit.days;
    }
  }

  String get storageValue {
    switch (this) {
      case IntervalUnit.hours:
        return 'hours';
      case IntervalUnit.days:
        return 'days';
      case IntervalUnit.weeks:
        return 'weeks';
      case IntervalUnit.months:
        return 'months';
    }
  }
}

// =============================================================================
// Drug 数据模型 — 支持双模式
// =============================================================================
///
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  模式 1：固定间隔（isDiscreteMode = false）                      │
/// │  例：每 12 小时 / 每 7 天 / 每 28 天                            │
/// │  → nextDoseTime = fromTime + intervalValue * intervalUnit       │
/// ├─────────────────────────────────────────────────────────────────┤
/// │  模式 2：日内离散（isDiscreteMode = true）                       │
/// │  → 条件：dailyReminderTimes 不为空                               │
/// │  例：['08:00', '20:00'] 每天早晚固定时刻                          │
/// │  → nextDoseTime = 从 fromTime 往后找最近的时刻                   │
/// └─────────────────────────────────────────────────────────────────┘
///
class Drug {
  // ───────────── 基础字段 ─────────────
  final String id;
  final String name;
  double currentStock;
  final double dosage;
  bool reminderEnabled;

  // ───────────── 模式 1：固定间隔参数 ─────────────
  int intervalValue; // 间隔数值（如 12）
  IntervalUnit intervalUnit; // 间隔单位（如 hours）

  // ───────────── 模式 2：日内离散参数 ─────────────
  // 固定时刻列表 ['08:00', '20:00']；非空时 isDiscreteMode = true
  List<String> dailyReminderTimes;

  // ───────────── 公共 ─────────────
  DateTime? nextDoseTime; // 计算得出的下次给药时间

  Drug({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.dosage,
    required this.intervalValue,
    required this.intervalUnit,
    this.nextDoseTime,
    List<String>? dailyReminderTimes,
    this.reminderEnabled = true,
  }) : dailyReminderTimes = dailyReminderTimes ?? [];

  // ==================== 模式判断 ====================

  /// true  → 日内离散模式（按 dailyReminderTimes 固定时刻）
  /// false → 固定间隔模式（按 intervalValue + intervalUnit）
  bool get isDiscreteMode => dailyReminderTimes.isNotEmpty;

  // ==================== 核心算法：计算下次服药时间 ====================

  /// 根据传入的 fromTime 推算下一次该什么时间服药。
  ///
  /// [fromTime] 通常是「本次服药」的实际时间。
  /// - 离散模式：在 dailyReminderTimes 中找 fromTime 之后最近的时刻
  /// - 固定间隔：fromTime + intervalValue * intervalUnit
  DateTime calculateNextDoseTime(DateTime fromTime) {
    if (isDiscreteMode) {
      return _nextDiscreteTime(fromTime);
    } else {
      return _nextFixedIntervalTime(fromTime);
    }
  }

  /// 日内离散模式：找 fromTime 之后最近的固定时刻
  ///
  /// 算法：
  /// 1. 将 dailyReminderTimes 排序（如 ['08:00', '20:00']）
  /// 2. 在今天内，找第一个严格大于 fromTime 的时刻
  /// 3. 如果今天所有时刻都已过去 → 返回明天的第一个时刻
  /// 将时间字符串规范化为 24h 格式的 (hour, minute)
  /// 支持 "08:00"、"4:10 AM"、"11:02PM"、"23:02" 等格式
  (int, int)? _normalizeTime(String raw) {
    var s = raw.trim().toUpperCase();
    bool isPM = false;
    bool isAM = false;

    if (s.endsWith(' PM')) {
      isPM = true;
      s = s.substring(0, s.length - 3).trim();
    } else if (s.endsWith('PM')) {
      isPM = true;
      s = s.substring(0, s.length - 2).trim();
    } else if (s.endsWith(' AM')) {
      isAM = true;
      s = s.substring(0, s.length - 3).trim();
    } else if (s.endsWith('AM')) {
      isAM = true;
      s = s.substring(0, s.length - 2).trim();
    }

    final parts = s.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    var hour24 = hour;
    if (isPM && hour != 12) hour24 = hour + 12;
    if (isAM && hour == 12) hour24 = 0;

    return (hour24, minute);
  }

  DateTime _nextDiscreteTime(DateTime fromTime) {
    // 排序
    final sorted = List<String>.from(dailyReminderTimes)
      ..sort((a, b) => a.compareTo(b));

    for (final timeStr in sorted) {
      final normalized = _normalizeTime(timeStr);
      if (normalized == null) continue;
      final hour = normalized.$1;
      final minute = normalized.$2;

      // 构建今天这一时刻的 DateTime
      final candidate = DateTime(
        fromTime.year,
        fromTime.month,
        fromTime.day,
        hour,
        minute,
      );

      // 严格大于 fromTime
      if (candidate.isAfter(fromTime)) {
        return candidate;
      }
    }

    // 今天的全部已过 → 取明天第一个时刻
    final first = sorted.first;
    final normalized = _normalizeTime(first);
    if (normalized == null) {
      // 兜底：无法解析时返回 1 小时后
      return fromTime.add(const Duration(hours: 1));
    }
    return DateTime(fromTime.year, fromTime.month, fromTime.day + 1,
        normalized.$1, normalized.$2);
  }

  /// 固定间隔模式：fromTime + intervalValue * intervalUnit
  DateTime _nextFixedIntervalTime(DateTime fromTime) {
    switch (intervalUnit) {
      case IntervalUnit.hours:
        return fromTime.add(Duration(hours: intervalValue));

      case IntervalUnit.days:
        return fromTime.add(Duration(days: intervalValue));

      case IntervalUnit.weeks:
        return fromTime.add(Duration(days: intervalValue * 7));

      case IntervalUnit.months:
        // 使用 DateTime 构造函数处理月份自然溢出
        // 例如 1月31日 + 1个月 → 2月28/29日（自动修正）
        return DateTime(
          fromTime.year,
          fromTime.month + intervalValue,
          fromTime.day,
          fromTime.hour,
          fromTime.minute,
          fromTime.second,
        );
    }
  }

  // ==================== 核心操作 ====================

  /// 记录一次服药：扣减库存 + 推算下次给药时间
  void recordDose() {
    currentStock = (currentStock - dosage).clamp(0.0, double.infinity);
    final now = DateTime.now();
    final newTime = calculateNextDoseTime(now);
    debugPrint('💊 [TP-Drug] recordDose: isDiscreteMode=$isDiscreteMode');
    debugPrint(
        '💊 [TP-Drug]   intervalValue=$intervalValue, intervalUnit=$intervalUnit');
    debugPrint('💊 [TP-Drug]   dailyReminderTimes=$dailyReminderTimes');
    debugPrint('💊 [TP-Drug]   now=$now');
    debugPrint('💊 [TP-Drug]   newTime=$newTime');
    nextDoseTime = newTime;
    debugPrint('💊 [TP-Drug]   nextDoseTime已设置为: $nextDoseTime');
  }

  /// 手动设置下次给药时间
  void setNextDoseTime(DateTime? time) {
    nextDoseTime = time;
  }

  /// 补仓
  void addStock(double amount) {
    if (amount > 0) {
      currentStock += amount;
    }
  }

  // ==================== 计算属性（为了旧兼容保留，底层改用新字段） ====================

  /// 将间隔转换为「小时」单位（用于库存估算）
  double get _intervalInHours {
    switch (intervalUnit) {
      case IntervalUnit.hours:
        return intervalValue.toDouble();
      case IntervalUnit.days:
        return (intervalValue * 24).toDouble();
      case IntervalUnit.weeks:
        return (intervalValue * 7 * 24).toDouble();
      case IntervalUnit.months:
        return (intervalValue * 30 * 24).toDouble();
    }
  }

  /// 每天消耗量
  double get dailyBurnRate {
    final hours = _intervalInHours;
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

  // ==================== UI 辅助 ====================

  /// 格式化周期描述
  /// 离散模式：「每日 08:00, 20:00」
  /// 固定间隔：「每 12 小时」/「每 7 天」
  String get cycleLabel {
    if (isDiscreteMode) {
      return '每日 ${dailyReminderTimes.join(', ')}';
    }
    return '每 $intervalValue ${intervalUnit.label}';
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
      // 模式 1：固定间隔
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit.storageValue,
      // 模式 2：日内离散
      'dailyReminderTimes': dailyReminderTimes,
      // 公共
      'nextDoseTime': nextDoseTime?.toIso8601String(),
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

      // 新字段优先；若不存在则从旧字段 cycleValue/cycleUnit 迁移
      intervalValue: json['intervalValue'] != null
          ? (json['intervalValue'] as num).toInt()
          : (json['cycleValue'] as num?)?.toInt() ?? 12,

      intervalUnit: json['intervalUnit'] != null
          ? IntervalUnit.fromString(json['intervalUnit'] as String)
          : IntervalUnit.fromString(json['cycleUnit'] as String? ?? 'hours'),

      dailyReminderTimes: json['dailyReminderTimes'] != null
          ? List<String>.from(json['dailyReminderTimes'] as List)
          : List<String>.from(json['reminderTimes'] as List? ?? []),

      nextDoseTime: nextDoseStr != null ? DateTime.parse(nextDoseStr) : null,
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
    int? intervalValue,
    IntervalUnit? intervalUnit,
    List<String>? dailyReminderTimes,
    DateTime? nextDoseTime,
    bool? reminderEnabled,
  }) {
    return Drug(
      id: id ?? this.id,
      name: name ?? this.name,
      currentStock: currentStock ?? this.currentStock,
      dosage: dosage ?? this.dosage,
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      dailyReminderTimes:
          dailyReminderTimes ?? List<String>.from(this.dailyReminderTimes),
      nextDoseTime: nextDoseTime ?? this.nextDoseTime,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }
}

import 'dart:convert';

/// 单次用药执行记录
///
/// 将"用药执行动作"从"定时提醒"中解耦。
/// 每次用药执行（手动或通过提醒）均生成一条日志，
/// 为后续的"部位轮换"等功能提供数据基础。
class MedicationLog {
  /// 唯一标识
  final String id;

  /// 对应的药物 ID
  final String medicationId;

  /// 用药时间
  final DateTime timestamp;

  /// 本次剂量
  final double dosage;

  /// 注射部位（可选）- 用于后续部位轮换功能
  /// 向后兼容：反序列化时允许该字段为空
  final String? injectionSite;

  /// 备注（可选）
  final String? note;

  MedicationLog({
    required this.id,
    required this.medicationId,
    required this.timestamp,
    required this.dosage,
    this.injectionSite,
    this.note,
  });

  // ==================== JSON 序列化 ====================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicationId': medicationId,
      'timestamp': timestamp.toIso8601String(),
      'dosage': dosage,
      if (injectionSite != null) 'injectionSite': injectionSite,
      if (note != null) 'note': note,
    };
  }

  factory MedicationLog.fromJson(Map<String, dynamic> json) {
    return MedicationLog(
      id: json['id'] as String,
      medicationId: json['medicationId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      dosage: (json['dosage'] as num).toDouble(),
      // 向后兼容：injectionSite 为可选字段，允许为空
      injectionSite: json['injectionSite'] as String?,
      note: json['note'] as String?,
    );
  }

  // ==================== 批量操作 ====================

  static List<MedicationLog> listFromJson(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => MedicationLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<MedicationLog> logs) {
    return jsonEncode(logs.map((l) => l.toJson()).toList());
  }

  // ==================== 便捷方法 ====================

  MedicationLog copyWith({
    String? id,
    String? medicationId,
    DateTime? timestamp,
    double? dosage,
    String? injectionSite,
    String? note,
    bool clearInjectionSite = false,
    bool clearNote = false,
  }) {
    return MedicationLog(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      timestamp: timestamp ?? this.timestamp,
      dosage: dosage ?? this.dosage,
      injectionSite:
          clearInjectionSite ? null : (injectionSite ?? this.injectionSite),
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

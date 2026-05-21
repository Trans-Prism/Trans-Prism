import 'f0_result.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 嗓音训练事件类型
enum VoiceEventType {
  /// 快速基频测试
  quickF0Test,

  /// 嗓音训练
  voiceTraining,

  /// 自我练习
  selfPractice,

  /// 嗓音手术
  surgery,

  /// 感受记录
  feelingLog,
}

/// 嗓音事件记录
class VoiceEvent {
  /// 唯一标识
  final String id;

  /// 事件类型
  final VoiceEventType type;

  /// 事件发生日期
  final DateTime date;

  /// 快速基频测试结果（仅 type==quickF0Test 时有效）
  final QuickF0TestResult? f0TestResult;

  /// 主观评估 - RBH 量表
  final RBHScore? rbhScore;

  /// 主观评估 - TVQ-G 量表（12项，每项0-4分）
  final List<int>? tvqgScores;

  /// 主观评估 - OVHS-9 量表（9项，每项0-4分）
  final List<int>? ovhs9Scores;

  /// 备注
  final String? notes;

  /// 创建时间
  final DateTime createdAt;

  const VoiceEvent({
    required this.id,
    required this.type,
    required this.date,
    this.f0TestResult,
    this.rbhScore,
    this.tvqgScores,
    this.ovhs9Scores,
    this.notes,
    required this.createdAt,
  });

  factory VoiceEvent.quickF0Test({
    required QuickF0TestResult result,
    String? notes,
  }) {
    return VoiceEvent(
      id: _uuid.v4(),
      type: VoiceEventType.quickF0Test,
      date: result.testTime,
      f0TestResult: result,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  factory VoiceEvent.voiceTraining({
    RBHScore? rbhScore,
    List<int>? tvqgScores,
    List<int>? ovhs9Scores,
    String? notes,
  }) {
    return VoiceEvent(
      id: _uuid.v4(),
      type: VoiceEventType.voiceTraining,
      date: DateTime.now(),
      rbhScore: rbhScore,
      tvqgScores: tvqgScores,
      ovhs9Scores: ovhs9Scores,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date.toIso8601String(),
        'f0TestResult': f0TestResult?.toJson(),
        'rbhScore': rbhScore?.toJson(),
        'tvqgScores': tvqgScores,
        'ovhs9Scores': ovhs9Scores,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VoiceEvent.fromJson(Map<String, dynamic> json) => VoiceEvent(
        id: json['id'] as String,
        type: VoiceEventType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => VoiceEventType.voiceTraining,
        ),
        date: DateTime.parse(json['date'] as String),
        f0TestResult: json['f0TestResult'] != null
            ? QuickF0TestResult.fromJson(
                json['f0TestResult'] as Map<String, dynamic>)
            : null,
        rbhScore: json['rbhScore'] != null
            ? RBHScore.fromJson(json['rbhScore'] as Map<String, dynamic>)
            : null,
        tvqgScores: json['tvqgScores'] != null
            ? (json['tvqgScores'] as List).cast<int>()
            : null,
        ovhs9Scores: json['ovhs9Scores'] != null
            ? (json['ovhs9Scores'] as List).cast<int>()
            : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// RBH 量表评分
/// R: 粗糙度 (Roughness)
/// B: 气息感 (Breathiness)
/// H: 嘶哑度 (Hoarseness)
/// 每项 0-3 分
class RBHScore {
  final int roughness; // R
  final int breathiness; // B
  final int hoarseness; // H

  const RBHScore({
    required this.roughness,
    required this.breathiness,
    required this.hoarseness,
  });

  int get total => roughness + breathiness + hoarseness;

  Map<String, dynamic> toJson() => {
        'roughness': roughness,
        'breathiness': breathiness,
        'hoarseness': hoarseness,
      };

  factory RBHScore.fromJson(Map<String, dynamic> json) => RBHScore(
        roughness: json['roughness'] as int,
        breathiness: json['breathiness'] as int,
        hoarseness: json['hoarseness'] as int,
      );
}

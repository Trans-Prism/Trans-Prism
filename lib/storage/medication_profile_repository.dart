import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 用户用药配置本地持久化存储
///
/// 存储 "用户自定义药物名称 → 轮换模板 ID" 的映射关系。
/// 用于后续部位轮换功能，将用户自定义药物与预设轮换模板关联。
///
/// 数据格式：Map<String, String>
/// - 键：用户自定义的药物名称（如 "雌二醇注射液"）
/// - 值：轮换模板 ID（如 "belly_4"）
///
/// 存储位置：SharedPreferences key "userMedicationProfiles"
class MedicationProfileRepository {
  static const String _storageKey = 'userMedicationProfiles';

  // ──────────────────────────────────────────────
  // 读取与写入
  // ──────────────────────────────────────────────

  /// 获取所有药物 → 轮换模板的映射
  Future<Map<String, String>> getAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  /// 保存完整的映射表
  Future<void> saveAllProfiles(Map<String, String> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(profiles));
  }

  // ──────────────────────────────────────────────
  // 单条操作
  // ──────────────────────────────────────────────

  /// 获取指定药物绑定的轮换模板 ID
  ///
  /// 返回 null 表示该药物尚未绑定轮换模板。
  Future<String?> getTemplateIdForDrug(String drugName) async {
    final profiles = await getAllProfiles();
    return profiles[drugName];
  }

  /// 为指定药物绑定轮换模板
  Future<void> setTemplateForDrug(String drugName, String templateId) async {
    final profiles = await getAllProfiles();
    profiles[drugName] = templateId;
    await saveAllProfiles(profiles);
  }

  /// 移除指定药物的轮换模板绑定
  Future<void> removeTemplateForDrug(String drugName) async {
    final profiles = await getAllProfiles();
    profiles.remove(drugName);
    await saveAllProfiles(profiles);
  }

  /// 检查指定药物是否已绑定轮换模板
  Future<bool> hasTemplateForDrug(String drugName) async {
    final templateId = await getTemplateIdForDrug(drugName);
    return templateId != null && templateId.isNotEmpty;
  }

  // ──────────────────────────────────────────────
  // 批量管理
  // ──────────────────────────────────────────────

  /// 清除所有映射关系
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// 获取所有已绑定模板的药物名称列表
  Future<List<String>> getDrugsWithTemplates() async {
    final profiles = await getAllProfiles();
    return profiles.keys.toList();
  }
}

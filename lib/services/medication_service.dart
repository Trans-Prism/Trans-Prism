import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/injection_templates.dart';
import '../models/drug_model.dart';
import '../models/medication_log.dart';
import '../storage/medication_profile_repository.dart';
import 'notification_service.dart';

/// 核心用药服务
///
/// 职责：将"用药执行动作"与"定时提醒"完全解耦。
/// - `executeMedicationDose()` 是纯数据层操作，不涉及任何 UI
/// - 负责记录用药日志、扣减库存、更新下次服药时间
/// - 不处理任何弹窗、Toast 等 UI 交互
///
/// 使用方式：
/// ```dart
/// final log = await MedicationService.executeMedicationDose(
///   drugId,
///   site: '左臂',
/// );
/// ```
class MedicationService {
  static const String _drugStorageKey = 'drug_inventory_list';
  static const String _logStorageKey = 'medication_logs';

  MedicationService._(); // 私有构造，纯静态服务

  static final NotificationService _notificationService = NotificationService();
  static const Uuid _uuid = Uuid();

  // ──────────────────────────────────────────────
  // 核心方法：执行一次用药
  // ──────────────────────────────────────────────

  /// 执行一次用药剂量
  ///
  /// 这是一个纯数据层方法：
  /// 1. 记录一条新的 MedicationLog（携带部位信息）
  /// 2. 扣除对应的本地库存
  /// 3. 计算并更新下一次需要服药的时间
  /// 4. 重新调度本地通知提醒
  ///
  /// [medId] 药物 ID
  /// [site]  注射部位（可选），为后续部位轮换功能预留
  ///
  /// 返回创建的 MedicationLog；如果药物未找到则返回 null。
  ///
  /// ⚠️ 注意：该方法不处理任何 UI 弹窗或 Toast，只做纯数据更新。
  static Future<MedicationLog?> executeMedicationDose(
    String medId, {
    String? site,
  }) async {
    debugPrint('💊 [TP-MedSvc] ===== executeMedicationDose =====');
    debugPrint('💊 [TP-MedSvc] medId=$medId, site=$site');

    final prefs = await SharedPreferences.getInstance();

    // ── 1. 加载药物列表并查找目标药物 ──
    final drugs = await _loadDrugs(prefs);
    final drugIndex = drugs.indexWhere((d) => d.id == medId);

    if (drugIndex == -1) {
      debugPrint('💊 [TP-MedSvc] ❌ 未找到药物 medId=$medId');
      return null;
    }

    final drug = drugs[drugIndex];
    debugPrint('💊 [TP-MedSvc] 药物: ${drug.name}');
    debugPrint('💊 [TP-MedSvc] 当前库存: ${drug.currentStock}');
    debugPrint('💊 [TP-MedSvc] 剂量: ${drug.dosage}');

    // ── 2. 创建用药日志 ──
    final log = MedicationLog(
      id: _uuid.v4(),
      medicationId: medId,
      timestamp: DateTime.now(),
      dosage: drug.dosage,
      injectionSite: site,
    );
    debugPrint('💊 [TP-MedSvc] 日志已创建: id=${log.id}');

    // ── 3. 扣减库存 + 计算下次服药时间 ──
    // 使用 Drug 模型中已有的 recordDose() 方法
    drug.recordDose();
    debugPrint(
        '💊 [TP-MedSvc] 库存更新: ${drug.currentStock + drug.dosage} → ${drug.currentStock}');
    debugPrint('💊 [TP-MedSvc] 下次服药时间: ${drug.nextDoseTime}');

    // ── 4. 持久化药物列表 ──
    await _saveDrugs(prefs, drugs);
    debugPrint('💊 [TP-MedSvc] 药物列表已持久化');

    // ── 5. 持久化用药日志 ──
    await _saveLog(prefs, log);
    debugPrint('💊 [TP-MedSvc] 用药日志已持久化');

    // ── 6. 重新调度通知提醒（携带推荐部位） ──
    await _notificationService.scheduleMedicineReminder(
      drug,
      recommendedSite: site,
    );
    debugPrint('💊 [TP-MedSvc] 通知已重新调度');

    debugPrint('💊 [TP-MedSvc] ===== 完成 =====');
    return log;
  }

  // ──────────────────────────────────────────────
  // 药物列表读写（与 InventoryDashboardScreen 共享同一存储）
  // ──────────────────────────────────────────────

  /// 从 SharedPreferences 加载药物列表
  static Future<List<Drug>> loadAllDrugs() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadDrugs(prefs);
  }

  static Future<List<Drug>> _loadDrugs(SharedPreferences prefs) async {
    final jsonStr = prefs.getString(_drugStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    return Drug.listFromJson(jsonStr);
  }

  static Future<void> _saveDrugs(
      SharedPreferences prefs, List<Drug> drugs) async {
    await prefs.setString(_drugStorageKey, Drug.listToJson(drugs));
  }

  // ──────────────────────────────────────────────
  // 用药日志读写
  // ──────────────────────────────────────────────

  /// 获取指定药物的所有用药日志（按时间降序排列）
  static Future<List<MedicationLog>> getLogsForDrug(String medId) async {
    final allLogs = await getAllLogs();
    return allLogs.where((log) => log.medicationId == medId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 获取所有用药日志（按时间降序排列）
  static Future<List<MedicationLog>> getAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_logStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    return MedicationLog.listFromJson(jsonStr)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 持久化单条用药日志（追加到日志列表）
  static Future<void> _saveLog(
      SharedPreferences prefs, MedicationLog log) async {
    final existing = await _loadLogs(prefs);
    existing.add(log);
    await prefs.setString(_logStorageKey, MedicationLog.listToJson(existing));
  }

  static Future<List<MedicationLog>> _loadLogs(SharedPreferences prefs) async {
    final jsonStr = prefs.getString(_logStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    return MedicationLog.listFromJson(jsonStr);
  }

  /// 批量保存所有日志（覆盖写入）
  static Future<void> saveAllLogs(List<MedicationLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logStorageKey, MedicationLog.listToJson(logs));
  }

  /// 获取指定药物的最近一次注射部位
  ///
  /// 用于部位轮换功能，确定上一次注射的部位。
  static Future<String?> getLastInjectionSite(String medId) async {
    final logs = await getLogsForDrug(medId);
    for (final log in logs) {
      if (log.injectionSite != null && log.injectionSite!.isNotEmpty) {
        return log.injectionSite;
      }
    }
    return null;
  }

  /// 获取指定药物的近期注射部位列表（去重，按最近使用排序）
  ///
  /// 用于部位轮换推荐算法。
  static Future<List<String>> getRecentSites(String medId) async {
    final logs = await getLogsForDrug(medId);
    final seen = <String>{};
    final sites = <String>[];
    for (final log in logs) {
      if (log.injectionSite != null &&
          log.injectionSite!.isNotEmpty &&
          seen.add(log.injectionSite!)) {
        sites.add(log.injectionSite!);
      }
    }
    return sites;
  }

  /// 清除指定药物的所有日志
  static Future<void> clearLogsForDrug(String medId) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await _loadLogs(prefs);
    logs.removeWhere((log) => log.medicationId == medId);
    await prefs.setString(_logStorageKey, MedicationLog.listToJson(logs));
  }

  /// 清除所有日志
  static Future<void> clearAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logStorageKey);
  }

  // ──────────────────────────────────────────────
  // 智能部位推荐
  // ──────────────────────────────────────────────

  /// 根据药物 ID 智能推导下次推荐注射部位
  ///
  /// 算法：读取该药物最新的一条历史记录，如果在模板列表中找到上次的部位，
  /// 计算出 (index + 1) % length 作为下次推荐部位。
  ///
  /// [medId] 药物 ID
  /// 返回推荐部位名称；如果无法推导返回 null。
  static Future<String?> calculateNextSite(String medId) async {
    final logs = await getLogsForDrug(medId);
    if (logs.isEmpty) return null;

    // 获取该药物绑定的模板 ID
    final drugs = await loadAllDrugs();
    final drug = drugs.where((d) => d.id == medId).firstOrNull;
    if (drug == null) return null;

    final profileRepo = MedicationProfileRepository();
    final templateId = await profileRepo.getTemplateIdForDrug(drug.name);
    if (templateId == null) return null;

    final sites = injectionTemplates[templateId];
    if (sites == null || sites.isEmpty) return null;

    // 找最近一次有部位记录的日志
    for (final log in logs) {
      if (log.injectionSite != null && log.injectionSite!.isNotEmpty) {
        final lastSite = log.injectionSite!;
        final lastIndex = sites.indexOf(lastSite);
        if (lastIndex != -1) {
          // (index + 1) % length → 轮换推荐
          return sites[(lastIndex + 1) % sites.length];
        }
      }
    }

    // 无历史记录，返回模板第一个部位
    return sites.first;
  }

  /// 根据药物名称智能推导下次推荐注射部位
  ///
  /// 先通过药物名称查找药物 ID，再委托 [calculateNextSite] 进行推导。
  static Future<String?> calculateNextSiteByName(String drugName) async {
    final drugs = await loadAllDrugs();
    // 可能有同名药物，取第一个匹配的
    final drug = drugs.where((d) => d.name == drugName).firstOrNull;
    if (drug == null) return null;
    return calculateNextSite(drug.id);
  }
}

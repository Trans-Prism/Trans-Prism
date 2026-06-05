import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// =============================================================================
/// PermissionManager — 权限与保活管理单例
///
/// 职责：
///   1. 统一封装 Android 通知权限、精确闹钟权限、忽略电池优化权限的申请逻辑
///   2. 提供便捷的「一键请求所有关键权限」入口
///   3. 上层 UI 只需关注「请求结果」，无需处理平台细节
///
/// 依赖：仅 permission_handler，无其他第三方包。
/// =============================================================================
class PermissionManager {
  // ─── 单例 ─────────────────────────────────────────────────
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  // ============================================================
  //  1. 通知权限（Android 13+ / iOS）
  // ============================================================

  /// 请求通知权限
  ///
  /// - Android 13 (API 33+)：弹出系统对话框
  /// - Android 12 及以下：系统默认授予，直接返回 true
  /// - iOS：通过 permission_handler 统一处理
  Future<bool> requestNotificationPermission() async {
    debugPrint('🔐 [PermissionManager] requestNotificationPermission()');

    // Android 12 及以下无需请求通知权限
    if (Platform.isAndroid && Platform.version.startsWith('1')) {
      // 极早期版本兜底
      return true;
    }

    final status = await ph.Permission.notification.request();
    final granted = status.isGranted;
    debugPrint(
        '🔐 [PermissionManager] notification → $status (granted=$granted)');
    return granted;
  }

  // ============================================================
  //  2. 精确闹钟权限（Android 12+）
  // ============================================================

  /// 申请精确闹钟权限
  ///
  /// - Android 12 (API 31)+：使用 [SCHEDULE_EXACT_ALARM] 权限
  /// - 通过 permission_handler 的 [Permission.scheduleExactAlarm] 统一处理
  /// - 返回 false 时 UI 层可引导用户前往系统设置手动授权
  Future<bool> requestExactAlarmPermission() async {
    debugPrint('🔐 [PermissionManager] requestExactAlarmPermission()');

    // 检查当前状态
    var status = await ph.Permission.scheduleExactAlarm.status;
    debugPrint('🔐 [PermissionManager] scheduleExactAlarm status → $status');

    if (status.isGranted) {
      return true;
    }

    // 发起请求（部分设备可能弹系统对话框，部分直接跳转设置）
    status = await ph.Permission.scheduleExactAlarm.request();
    debugPrint('🔐 [PermissionManager] scheduleExactAlarm request → $status');

    return status.isGranted;
  }

  // ============================================================
  //  3. 忽略电池优化（Android 6+）
  // ============================================================

  /// 检查并请求忽略电池优化权限
  ///
  /// Android 会弹出系统对话框，用户选择「允许」后应用将加入电池白名单。
  /// 如果用户拒绝，UI 层应引导用户前往系统设置手动开启。
  ///
  /// 返回值：
  ///   - true  → 已处于「忽略电池优化」状态
  ///   - false → 用户拒绝了请求
  Future<bool> requestIgnoreBatteryOptimization() async {
    debugPrint('🔐 [PermissionManager] requestIgnoreBatteryOptimization()');

    // 检查当前状态
    var status = await ph.Permission.ignoreBatteryOptimizations.status;
    debugPrint(
        '🔐 [PermissionManager] ignoreBatteryOptimizations status → $status');

    if (status.isGranted) {
      debugPrint('✅ [PermissionManager] 已处于忽略电池优化状态');
      return true;
    }

    // 发起系统对话框请求
    status = await ph.Permission.ignoreBatteryOptimizations.request();
    debugPrint(
        '🔐 [PermissionManager] ignoreBatteryOptimizations request → $status');

    return status.isGranted;
  }

  // ============================================================
  //  4. 自启动权限（引导跳转，依赖机型）
  // ============================================================

  /// 引导用户前往系统设置页面
  ///
  /// 由于 Android 厂商（小米、华为、OPPO、vivo 等）各自管控自启动，
  /// 无法通过单一 API 授权，只能通过 [openAppSettings] 引导用户手动开启。
  Future<bool> openAutoStartSettings() async {
    debugPrint('🔐 [PermissionManager] openAutoStartSettings()');

    final settingsOpened = await ph.openAppSettings();
    debugPrint('🔐 [PermissionManager] openAppSettings → $settingsOpened');
    return settingsOpened;
  }

  // ============================================================
  //  5. 批量请求（一站式启动入口）
  // ============================================================

  /// 一键请求所有关键权限，按依赖关系顺序执行
  ///
  /// 返回一个 Map，包含每种权限的结果：
  /// ```dart
  /// {
  ///   'notification': true,
  ///   'exact_alarm': false,
  ///   'battery_optimization': true,
  /// }
  /// ```
  Future<Map<String, bool>> requestAllCriticalPermissions() async {
    debugPrint(
        '🔐 [PermissionManager] ==== requestAllCriticalPermissions ====');

    final notificationGranted = await requestNotificationPermission();
    final exactAlarmGranted = await requestExactAlarmPermission();
    final batteryOptGranted = await requestIgnoreBatteryOptimization();

    final result = <String, bool>{
      'notification': notificationGranted,
      'exact_alarm': exactAlarmGranted,
      'battery_optimization': batteryOptGranted,
    };

    debugPrint('🔐 [PermissionManager] 批量权限请求结果: $result');
    debugPrint(
        '🔐 [PermissionManager] ==== requestAllCriticalPermissions 完成 ====');

    return result;
  }

  // ============================================================
  //  6. 状态查询工具（不请求，仅检查）
  // ============================================================

  /// 查询当前所有关键权限的状态
  Future<Map<String, bool>> checkPermissionStatuses() async {
    final notificationStatus = await ph.Permission.notification.status;
    final exactAlarmStatus = await ph.Permission.scheduleExactAlarm.status;
    final batteryOptStatus =
        await ph.Permission.ignoreBatteryOptimizations.status;

    return {
      'notification': notificationStatus.isGranted,
      'exact_alarm': exactAlarmStatus.isGranted,
      'battery_optimization': batteryOptStatus.isGranted,
    };
  }

  // ============================================================
  //  7. 跳转系统设置
  // ============================================================

  /// 打开应用的系统设置页面
  Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }
}

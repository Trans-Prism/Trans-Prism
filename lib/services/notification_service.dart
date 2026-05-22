import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/drug_model.dart';

/// 本地通知服务单例 — Chronos 通知引擎
///
/// 支持两套调度策略：
/// 1. 锚点调度：基于 nextDoseTime 注册绝对时间的单次通知（适合长效针剂/贴片）
/// 2. 每日重复：基于 reminderTimes 注册每日固定时间重复通知（适合短效口服药）
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 通知点击回调：携带药物 ID，用于触发库存扣减 + 自动推算下次时间
  void Function(String drugId)? onDoseRecorded;

  // ==================== 初始化 ====================

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final drugId = response.payload;
    if (drugId != null && drugId.isNotEmpty) {
      onDoseRecorded?.call(drugId);
    }
  }

  // ==================== 权限检查 ====================

  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> hasPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    return await androidPlugin.areNotificationsEnabled() ?? false;
  }

  // ==================== Chronos 通知调度引擎 ====================

  /// 为指定药物调度所有提醒（锚点通知 + 每日重复）
  Future<void> scheduleMedicineReminder(Drug drug) async {
    // 先取消旧提醒
    await cancelDrugReminders(drug.id);

    if (!drug.reminderEnabled) return;

    // ── 1. 锚点通知：基于 nextDoseTime ──
    if (drug.nextDoseTime != null &&
        drug.nextDoseTime!.isAfter(DateTime.now())) {
      await _scheduleNextDoseNotification(drug);
    }

    // ── 2. 每日固定时间提醒（短效药物用） ──
    // 仅当周期 ≤ 1 天时，每日提醒才有意义
    if (_isShortCycle(drug) && drug.reminderTimes.isNotEmpty) {
      await _scheduleDailyReminders(drug);
    }
  }

  /// 判断是否为短周期药物（周期 ≤ 1 天）
  bool _isShortCycle(Drug drug) {
    switch (drug.cycleUnit) {
      case CycleUnit.hours:
        return drug.cycleValue <= 24;
      case CycleUnit.days:
        return drug.cycleValue <= 1;
      case CycleUnit.weeks:
        return drug.cycleValue <= 1 / 7; // 约 0.14 周 ≈ 1 天
      case CycleUnit.months:
        return false; // 月周期绝不触发每日提醒
    }
  }

  /// 调度基于 nextDoseTime 的单次锚点通知
  Future<void> _scheduleNextDoseNotification(Drug drug) async {
    final doseTime = drug.nextDoseTime!;
    final tzDoseTime = tz.TZDateTime.from(doseTime, tz.local);

    if (tzDoseTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    final androidDetails = AndroidNotificationDetails(
      'drug_anchor_channel',
      '用药锚定提醒',
      channelDescription: '基于 ${drug.name} 的下次给药时间触发的精准提醒',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      category: AndroidNotificationCategory.alarm,
      autoCancel: true,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      drug.id.hashCode, // 锚点通知使用基础 hash
      '💊 用药时间到',
      '伙伴，该使用 ${drug.name} 了。',
      tzDoseTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: drug.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // 不设置 matchDateTimeComponents — 这是单次通知
    );
  }

  /// 调度每日固定时间重复提醒（短周期药物专用）
  Future<void> _scheduleDailyReminders(Drug drug) async {
    for (int i = 0; i < drug.reminderTimes.length; i++) {
      final timeStr = drug.reminderTimes[i];
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final androidDetails = AndroidNotificationDetails(
        'drug_daily_channel',
        '每日用药提醒',
        channelDescription: '${drug.name} 的每日固定时间用药提醒',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        category: AndroidNotificationCategory.alarm,
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _plugin.zonedSchedule(
        drug.id.hashCode * 100 + i, // 每日提醒使用 hash*100 + index
        '💊 稳态补充提醒',
        '伙伴，该进行今日的稳态补充了。(${drug.name})',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: drug.id,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// 取消指定药物的所有计划提醒
  Future<void> cancelDrugReminders(String drugId) async {
    // 取消锚点通知
    await _plugin.cancel(drugId.hashCode);
    // 取消每日提醒（最多 10 个时间点）
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(drugId.hashCode * 100 + i);
    }
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 获取当前所有待处理的通知
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }
}

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/drug_model.dart';

// =============================================================================
// NotificationService 单例 — Chronos 通知引擎
// =============================================================================
///
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String drugId)? onDoseRecorded;
  void Function(String drugId)? onSnoozeRequested;

  // ==================== 初始化 ====================

  Future<void> initialize() async {
    print('🔍 [TP-Debug] NotificationService.initialize() 开始...');
    tz_data.initializeTimeZones();
    print('⏰ [TP-Debug] 时区数据已加载。当前 tz.local 时区: ${tz.local}');

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
    print('✅ [TP-Debug] 通知插件初始化完成。');
    await _requestExactAlarmPermission();
    print('✅ [TP-Debug] 精确闹钟权限请求完毕。');
  }

  void _onNotificationResponse(NotificationResponse response) {
    print(
        '🔍 [TP-Debug] 通知响应: actionId="${response.actionId}", payload="${response.payload}"');
    final drugId = response.payload;
    if (drugId == null || drugId.isEmpty) return;
    switch (response.actionId) {
      case 'take_dose':
        print('💊 [TP-Debug] 用户点击「已服药」, drugId=$drugId');
        onDoseRecorded?.call(drugId);
        break;
      case 'snooze_5min':
        print('⏰ [TP-Debug] 用户点击「5分钟后提醒」, drugId=$drugId');
        onSnoozeRequested?.call(drugId);
        break;
      default:
        print('💊 [TP-Debug] 用户点击通知主体, drugId=$drugId');
        onDoseRecorded?.call(drugId);
        break;
    }
  }

  // ==================== 权限 ====================

  Future<bool> requestPermission() async {
    print('🔍 [TP-Debug] requestPermission() 开始...');
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    print('🔍 [TP-Debug] requestNotificationsPermission 结果: $granted');
    await _requestExactAlarmPermission();
    return granted ?? false;
  }

  Future<void> _requestExactAlarmPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    try {
      await androidPlugin.requestExactAlarmsPermission();
      print('✅ [TP-Debug] requestExactAlarmsPermission 成功');
    } catch (e) {
      print('⚠️ [TP-Debug] requestExactAlarmsPermission 异常(非致命): $e');
    }
  }

  Future<bool> hasPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    return await androidPlugin.areNotificationsEnabled() ?? false;
  }

  // ==================== ID 生成 ====================

  int _safeNotifyId(String drugId, {int offset = 0}) {
    return (drugId.hashCode.abs() % 2147483646) + offset + 1;
  }

  // ==================== 通知模板 ====================

  AndroidNotificationDetails _buildAndroidDetails({
    required String channelId,
    required String channelName,
    String channelDesc = '',
    bool highImportance = true,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: highImportance ? Importance.max : Importance.high,
      priority: highImportance ? Priority.max : Priority.high,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      category: AndroidNotificationCategory.alarm,
      autoCancel: true,
      fullScreenIntent: highImportance,
      usesChronometer: highImportance,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'take_dose',
          '已服药',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'snooze_5min',
          '5分钟后提醒',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
  }

  NotificationDetails _buildDetails({
    required String channelId,
    required String channelName,
    String channelDesc = '',
    bool highImportance = true,
  }) {
    return NotificationDetails(
      android: _buildAndroidDetails(
        channelId: channelId,
        channelName: channelName,
        channelDesc: channelDesc,
        highImportance: highImportance,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ==================== 调度引擎 ====================

  Future<void> scheduleMedicineReminder(Drug drug) async {
    print('🔍 [TP-Debug] ==== scheduleMedicineReminder 开始 ====');
    print('🔍 [TP-Debug] 药物: ${drug.name}, ID: ${drug.id}');
    print('🔍 [TP-Debug] 模式: ${drug.isDiscreteMode ? "日内离散" : "固定间隔"}');
    print('🔍 [TP-Debug] reminderEnabled: ${drug.reminderEnabled}');
    print('🔍 [TP-Debug] nextDoseTime: ${drug.nextDoseTime}');
    print('🔍 [TP-Debug] dailyReminderTimes: ${drug.dailyReminderTimes}');
    print(
        '🔍 [TP-Debug] interval: ${drug.intervalValue} ${drug.intervalUnit.name}');

    if (!drug.reminderEnabled) {
      await cancelDrugReminders(drug.id);
      print('⚠️ [TP-Debug] 提醒未启用，已清空');
      return;
    }

    // 如果已有 nextDoseTime 且在未来，直接调度它
    // 否则不做任何事情（recordDose 时会调用 calculateNextDoseTime 设置 nextDoseTime）
    if (drug.nextDoseTime != null &&
        drug.nextDoseTime!.isAfter(DateTime.now())) {
      print('🔍 [TP-Debug] 调度 nextDoseTime=${drug.nextDoseTime}');
      await _scheduleOneShot(drug);
    } else {
      print('⚠️ [TP-Debug] nextDoseTime 为空或已过期，跳过调度');
    }

    print('✅ [TP-Debug] ==== scheduleMedicineReminder 完成 ====');
  }

  /// 针对一个绝对时间注册一次性提醒（同时注册 Timer 兜底）
  Future<void> _scheduleOneShot(Drug drug) async {
    final doseTime = drug.nextDoseTime!;
    final utcNow = DateTime.now().toUtc();
    final utcDose = doseTime.toUtc();
    final diff = utcDose.difference(utcNow);

    print('⏰ [TP-Debug] 时间差: ${diff.inSeconds} 秒');

    tz.TZDateTime scheduledDate;
    if (diff <= Duration.zero) {
      print('❌ [TP-Debug] 时间已过去！保底 10 秒');
      scheduledDate =
          tz.TZDateTime.from(utcNow.add(const Duration(seconds: 10)), tz.UTC);
    } else {
      scheduledDate = tz.TZDateTime.from(utcDose, tz.UTC);
    }

    final safeId = _safeNotifyId(drug.id);
    final diffSeconds =
        scheduledDate.difference(tz.TZDateTime.now(tz.UTC)).inSeconds;

    print('🚀 [TP-Debug] 距离触发 $diffSeconds 秒, ID=$safeId');

    final details = _buildDetails(
      channelId: 'drug_anchor_channel',
      channelName: '用药锚定提醒',
      channelDesc: '基于计算出的下次给药时间触发的精准用药提醒',
    );

    try {
      await _plugin.zonedSchedule(
        safeId,
        '💊 用药时间到',
        '伙伴，该使用 ${drug.name} 了。',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: drug.id,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('✅ [TP-Debug] zonedSchedule(alarmClock) 已挂载');
    } catch (e, stack) {
      print('💥 [TP-Debug] alarmClock 失败: $e');
      try {
        await _plugin.zonedSchedule(
          safeId,
          '💊 用药时间到',
          '伙伴，该使用 ${drug.name} 了。',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: drug.id,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        print('✅ [TP-Debug] 降级 exactAllowWhileIdle 成功');
      } catch (e2) {
        print('💥 [TP-Debug] 降级也失败: $e2');
      }
    }

    // Timer 前台兜底
    _scheduleTimerFallback(
      id: safeId,
      delay: Duration(seconds: diffSeconds),
      title: '💊 用药时间到',
      body: '伙伴，该使用 ${drug.name} 了。',
      drugId: drug.id,
    );

    print('✅ [TP-Debug] _scheduleOneShot 完成');
  }

  // ───────────────── Snooze ─────────────────

  Future<void> scheduleSnoozeReminder(String drugId, String drugName) async {
    print('⏰ [TP-Debug] scheduleSnoozeReminder: drugId=$drugId');

    final snoozeId = _safeNotifyId(drugId, offset: 99);
    const delay = Duration(minutes: 5);
    final target = DateTime.now().add(delay);

    print('⏰ [TP-Debug] Snooze ID: $snoozeId, 延迟: ${delay.inSeconds}秒');

    // Timer 兜底（已验证可工作）
    _scheduleTimerFallback(
      id: snoozeId,
      delay: delay,
      title: '💊 5分钟到了',
      body: '伙伴，该使用 $drugName 了。',
      drugId: drugId,
    );

    // zonedSchedule 系统级
    final details = _buildDetails(
      channelId: 'drug_snooze_channel',
      channelName: '用药提醒(5分钟后)',
      channelDesc: '用户点击「5分钟后」触发的延迟提醒',
    );
    try {
      await _plugin.zonedSchedule(
        snoozeId,
        '💊 5分钟到了',
        '伙伴，该使用 $drugName 了。',
        tz.TZDateTime.from(target.toUtc(), tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: drugId,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('✅ [TP-Debug] Snooze alarmClock 已挂载');
    } catch (e) {
      print('💥 [TP-Debug] Snooze alarmClock 失败: $e');
    }

    print('⏰ [TP-Debug] scheduleSnoozeReminder 完成');
  }

  // ───────────────── Timer 兜底 ─────────────────

  Timer? _scheduleTimerFallback({
    required int id,
    required Duration delay,
    required String title,
    required String body,
    required String drugId,
  }) {
    if (delay <= Duration.zero || delay > const Duration(days: 1)) {
      print('⏱ [TP-Debug] Timer 兜底跳过: delay=${delay.inSeconds}s');
      return null;
    }
    print('⏱ [TP-Debug] Timer 兜底注册: id=$id, ${delay.inSeconds}秒后');
    return Timer(delay, () async {
      print('⏱ [TP-Debug] >>> Timer 兜底触发！id=$id <<<');
      try {
        final details = _buildDetails(
          channelId: 'drug_timer_fallback_channel',
          channelName: '用药提醒(兜底)',
          channelDesc: 'Dart Timer 兜底用药提醒',
        );
        await _plugin.show(id, title, body, details, payload: drugId);
        print('✅ [TP-Debug] >>> Timer 兜底通知已弹出！id=$id <<<');
      } catch (e) {
        print('💥 [TP-Debug] Timer 兜底通知失败: $e');
      }
    });
  }

  // ==================== 即时通知测试 ====================

  Future<void> showImmediately() async {
    print('🔍 [TP-Debug] --- showImmediately ---');
    final details = _buildDetails(
      channelId: 'test_channel',
      channelName: '测试通知',
      channelDesc: '用于验证基础通知弹出能力',
    );
    await _plugin.show(8888, '🧪 即时测试', '基础通知通道正常！', details,
        payload: 'immediate_test');
    print('✅ [TP-Debug] show() 已调用');
  }

  Future<void> testFiveSecondsNotification() async {
    print('🔍 [TP-Debug] --- testFiveSecondsNotification 开始 ---');
    const testDelay = Duration(seconds: 5);
    const testId = 9999;

    final details = _buildDetails(
      channelId: 'test_channel',
      channelName: '测试通知',
      channelDesc: '用于验证调度引擎',
    );

    try {
      final now = tz.TZDateTime.now(tz.local);
      await _plugin.zonedSchedule(
        testId,
        '🧪 存活性测试',
        '如果这条通知在5秒后出现，说明 alarmClock 工作正常！',
        now.add(testDelay),
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('✅ [TP-Debug] 测试闹钟注册完毕！');
    } catch (e) {
      print('💥 [TP-Debug] 测试闹钟失败: $e');
    }

    _scheduleTimerFallback(
      id: testId,
      delay: testDelay,
      title: '🧪 存活性测试',
      body: 'Dart Timer 兜底触发的测试通知。',
      drugId: 'alarm_test',
    );
    print('✅ [TP-Debug] --- testFiveSecondsNotification 完成 ---');
  }

  Future<void> cancelTestNotification() async {
    await _plugin.cancel(9999);
  }

  // ==================== 取消操作 ====================

  Future<void> cancelDrugReminders(String drugId) async {
    print('🔍 [TP-Debug] cancelDrugReminders 开始, drugId: $drugId');
    await _plugin.cancel(_safeNotifyId(drugId));
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(_safeNotifyId(drugId, offset: i));
    }
    await _plugin.cancel(_safeNotifyId(drugId, offset: 99));
    print('✅ [TP-Debug] cancelDrugReminders 完成');
  }

  Future<void> cancelAll() async {
    print('🔍 [TP-Debug] cancelAll()');
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    print('🔍 [TP-Debug] 待处理通知数量: ${pending.length}');
    return pending;
  }
}

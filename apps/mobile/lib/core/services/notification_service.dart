import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'balanceflow_main';
  static const _channelName = 'BalanceFlow';
  static const _channelDesc = 'Transaction reminders and spending insights';

  // Notification IDs — stable so rescheduling replaces existing
  static const idDailyReminder = 1;
  static const idMorningNudge = 2;
  static const idWeeklySummary = 3;
  static const idStreak = 4;

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onTap,
    );
  }

  void _onTap(NotificationResponse response) {
    // App handles navigation via a global key if needed — for now just opens app
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // ── Notification details ───────────────────────────────────────────────────

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(''),
        ),
      );

  // ── Schedule helpers ───────────────────────────────────────────────────────

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextSunday(int hour, int minute) {
    var dt = _nextInstanceOfTime(hour, minute);
    while (dt.weekday != DateTime.sunday) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  // ── Schedule all active notifications ─────────────────────────────────────

  Future<void> scheduleAll({
    required bool enabled,
    required bool dailyReminder,
    required int dailyHour,
    required int dailyMinute,
    required bool morningNudge,
    required int nudgeHour,
    required int nudgeMinute,
    required bool weeklyEnabled,
    required bool streakEnabled,
    required int streakCount,
  }) async {
    // Cancel everything first, then reschedule what's active
    await _plugin.cancelAll();
    if (!enabled) return;

    if (dailyReminder) {
      await _scheduleDailyReminder(
          dailyHour, dailyMinute, streakEnabled, streakCount);
    }
    if (morningNudge) {
      await _scheduleMorningNudge(nudgeHour, nudgeMinute);
    }
    if (weeklyEnabled) {
      await _scheduleWeeklySummary();
    }
  }

  Future<void> _scheduleDailyReminder(
      int hour, int minute, bool withStreak, int streak) async {
    final body = withStreak && streak > 1
        ? "🔥 $streak-day streak! Don't break it — log today's expenses"
        : "Don't forget to log today's expenses 💸";

    await _plugin.zonedSchedule(idDailyReminder, 'BalanceFlow reminder', body,
        _nextInstanceOfTime(hour, minute), _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);

    // Schedule streak notification separately if needed
    if (withStreak && streak > 1) {
      await _plugin.zonedSchedule(
          idStreak,
          '🔥 $streak-day streak!',
          'You\'ve logged transactions for $streak days in a row. Keep it going!',
          _nextInstanceOfTime(hour, minute + 1 > 59 ? 0 : minute + 1),
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime);
    }
  }

  Future<void> _scheduleMorningNudge(int hour, int minute) async {
    await _plugin.zonedSchedule(
        idMorningNudge,
        'Good morning! 🌅',
        'Start your day right — log any expenses from last night',
        _nextInstanceOfTime(hour, minute),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> _scheduleWeeklySummary() async {
    await _plugin.zonedSchedule(
        idWeeklySummary,
        'Your weekly summary 📊',
        'Tap to see how you spent your money this week',
        _nextSunday(20, 0),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Fire immediate notification (for testing) ──────────────────────────────

  Future<void> fireTest() async {
    await _plugin.show(
      99,
      'BalanceFlow',
      'Notifications are working! 🎉',
      _details,
    );
  }
}

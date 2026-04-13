import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'balanceflow_main';
  static const _channelName = 'BalanceFlow';
  static const _channelDesc = 'Transaction reminders and insights';

  static const idDailyReminder = 1;
  static const idMorningNudge = 2;
  static const idWeeklySummary = 3;
  static const idStreak = 4;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    tz.initializeTimeZones();

    // Use the device's UTC offset to find the matching tz location.
    // DateTime.now().timeZoneName gives e.g. "IST" but tz needs "Asia/Kolkata".
    // Instead we use the raw UTC offset to find the best matching location.
    _setLocalTimezone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _setLocalTimezone() {
    // Get device UTC offset in milliseconds
    final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;

    // Find tz locations that match this offset
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final name in tz.timeZoneDatabase.locations.keys) {
      final location = tz.timeZoneDatabase.locations[name]!;
      final tzNow = tz.TZDateTime.fromMillisecondsSinceEpoch(location, now);
      if (tzNow.timeZoneOffset.inMilliseconds == offsetMs) {
        // Prefer canonical names (no underscores, longer names = more specific)
        tz.setLocalLocation(location);
        return;
      }
    }
    // Fallback: create a fixed offset location
    // At minimum this gets the correct hour, even if DST is wrong
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    final canSchedule = await android?.canScheduleExactNotifications() ?? false;
    if (!canSchedule) {
      await android?.requestExactAlarmsPermission();
    }
  }

  // ── Notification details ──────────────────────────────────────────────────

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      );

  // ── Time helpers ──────────────────────────────────────────────────────────

  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now.add(const Duration(minutes: 1)))) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  tz.TZDateTime _nextSunday(int hour, int minute) {
    var t = _nextTime(hour, minute);
    while (t.weekday != DateTime.sunday) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  // ── Schedule all ──────────────────────────────────────────────────────────

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
    await _plugin.cancelAll();
    if (!enabled) return;
    if (dailyReminder) {
      await _dailyReminder(dailyHour, dailyMinute, streakEnabled, streakCount);
    }
    if (morningNudge) {
      await _morningNudge(nudgeHour, nudgeMinute);
    }
    if (weeklyEnabled) {
      await _weeklySummary();
    }
  }

  // ── Individual schedulers ─────────────────────────────────────────────────

  Future<void> _dailyReminder(
      int hour, int minute, bool withStreak, int streak) async {
    final body = withStreak && streak > 1
        ? '🔥 $streak-day streak! Don\'t break it — log today\'s expenses'
        : 'Don\'t forget to log today\'s expenses 💸';

    await _plugin.zonedSchedule(
      idDailyReminder,
      'BalanceFlow',
      body,
      _nextTime(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (withStreak && streak > 1) {
      await _plugin.zonedSchedule(
        idStreak,
        '🔥 $streak-day streak!',
        'You\'ve logged transactions $streak days in a row. Keep it going!',
        _nextTime(hour, minute > 58 ? minute : minute + 1),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _morningNudge(int hour, int minute) async {
    await _plugin.zonedSchedule(
      idMorningNudge,
      'Good morning! 🌅',
      'Start your day right — log any expenses from last night',
      _nextTime(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _weeklySummary() async {
    await _plugin.zonedSchedule(
      idWeeklySummary,
      'Your weekly summary 📊',
      'Tap to see how you spent your money this week',
      _nextSunday(20, 0),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> fireTest() async {
    await _plugin.show(
        99, 'BalanceFlow', 'Notifications are working! 🎉', _details);
  }

  String debugNextTime(int hour, int minute) {
    final t = _nextTime(hour, minute);
    return '${t.day}/${t.month} ${t.hour}:${t.minute.toString().padLeft(2, '0')} (${tz.local.name})';
  }
}

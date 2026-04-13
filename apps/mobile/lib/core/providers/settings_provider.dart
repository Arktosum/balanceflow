import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kEnabled = 'notif_enabled';
const _kDailyReminder = 'notif_daily';
const _kDailyHour = 'notif_daily_hour';
const _kDailyMinute = 'notif_daily_minute';
const _kMorningNudge = 'notif_morning';
const _kNudgeHour = 'notif_nudge_hour';
const _kNudgeMinute = 'notif_nudge_minute';
const _kWeekly = 'notif_weekly';
const _kStreak = 'notif_streak';
const _kStreakCount = 'streak_count';
const _kLastLoggedDate = 'streak_last_date';

// ── Model ─────────────────────────────────────────────────────────────────────

class NotificationSettings {
  final bool enabled;
  final bool dailyReminder;
  final int dailyHour;
  final int dailyMinute;
  final bool morningNudge;
  final int nudgeHour;
  final int nudgeMinute;
  final bool weeklyEnabled;
  final bool streakEnabled;
  final int streakCount;

  const NotificationSettings({
    this.enabled = true,
    this.dailyReminder = true,
    this.dailyHour = 21,
    this.dailyMinute = 0,
    this.morningNudge = true,
    this.nudgeHour = 9,
    this.nudgeMinute = 0,
    this.weeklyEnabled = true,
    this.streakEnabled = true,
    this.streakCount = 0,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? dailyReminder,
    int? dailyHour,
    int? dailyMinute,
    bool? morningNudge,
    int? nudgeHour,
    int? nudgeMinute,
    bool? weeklyEnabled,
    bool? streakEnabled,
    int? streakCount,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        dailyHour: dailyHour ?? this.dailyHour,
        dailyMinute: dailyMinute ?? this.dailyMinute,
        morningNudge: morningNudge ?? this.morningNudge,
        nudgeHour: nudgeHour ?? this.nudgeHour,
        nudgeMinute: nudgeMinute ?? this.nudgeMinute,
        weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
        streakEnabled: streakEnabled ?? this.streakEnabled,
        streakCount: streakCount ?? this.streakCount,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, NotificationSettings>(
        SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<NotificationSettings> {
  late SharedPreferences _prefs;

  @override
  Future<NotificationSettings> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _load();
  }

  NotificationSettings _load() => NotificationSettings(
        enabled: _prefs.getBool(_kEnabled) ?? true,
        dailyReminder: _prefs.getBool(_kDailyReminder) ?? true,
        dailyHour: _prefs.getInt(_kDailyHour) ?? 21,
        dailyMinute: _prefs.getInt(_kDailyMinute) ?? 0,
        morningNudge: _prefs.getBool(_kMorningNudge) ?? true,
        nudgeHour: _prefs.getInt(_kNudgeHour) ?? 9,
        nudgeMinute: _prefs.getInt(_kNudgeMinute) ?? 0,
        weeklyEnabled: _prefs.getBool(_kWeekly) ?? true,
        streakEnabled: _prefs.getBool(_kStreak) ?? true,
        streakCount: _prefs.getInt(_kStreakCount) ?? 0,
      );

  Future<void> _save(NotificationSettings s) async {
    await Future.wait([
      _prefs.setBool(_kEnabled, s.enabled),
      _prefs.setBool(_kDailyReminder, s.dailyReminder),
      _prefs.setInt(_kDailyHour, s.dailyHour),
      _prefs.setInt(_kDailyMinute, s.dailyMinute),
      _prefs.setBool(_kMorningNudge, s.morningNudge),
      _prefs.setInt(_kNudgeHour, s.nudgeHour),
      _prefs.setInt(_kNudgeMinute, s.nudgeMinute),
      _prefs.setBool(_kWeekly, s.weeklyEnabled),
      _prefs.setBool(_kStreak, s.streakEnabled),
      _prefs.setInt(_kStreakCount, s.streakCount),
    ]);
  }

  Future<void> _reschedule(NotificationSettings s) =>
      NotificationService.instance.scheduleAll(
        enabled: s.enabled,
        dailyReminder: s.dailyReminder,
        dailyHour: s.dailyHour,
        dailyMinute: s.dailyMinute,
        morningNudge: s.morningNudge,
        nudgeHour: s.nudgeHour,
        nudgeMinute: s.nudgeMinute,
        weeklyEnabled: s.weeklyEnabled,
        streakEnabled: s.streakEnabled,
        streakCount: s.streakCount,
      );

  Future<void> save(NotificationSettings s) async {
    state = AsyncData(s);
    await _save(s);
    await _reschedule(s);
  }

  // ── Streak logic ───────────────────────────────────────────────────────────

  /// Call this on app open / after adding a transaction.
  /// Pass true if at least one transaction exists today.
  Future<void> checkStreak(bool hasTransactionToday) async {
    final lastDate = _prefs.getString(_kLastLoggedDate);
    final today = _todayKey();
    final yesterday = _yesterdayKey();

    int streak = _prefs.getInt(_kStreakCount) ?? 0;

    if (hasTransactionToday) {
      if (lastDate == today) {
        // Already counted today — no change
      } else if (lastDate == yesterday) {
        // Consecutive day — increment
        streak++;
      } else {
        // Gap — reset to 1
        streak = 1;
      }
      await _prefs.setString(_kLastLoggedDate, today);
      await _prefs.setInt(_kStreakCount, streak);

      final current = state.valueOrNull;
      if (current != null) {
        final updated = current.copyWith(streakCount: streak);
        state = AsyncData(updated);
        await _reschedule(updated);
      }
    } else {
      // No transactions today — streak is "at risk" but not yet broken
      // (broken only when we get data and yesterday also had none)
      if (lastDate != null && lastDate != today && lastDate != yesterday) {
        // More than a day gap — reset streak
        streak = 0;
        await _prefs.setInt(_kStreakCount, 0);
        final current = state.valueOrNull;
        if (current != null) {
          final updated = current.copyWith(streakCount: 0);
          state = AsyncData(updated);
          await _reschedule(updated);
        }
      }
    }
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayKey() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/notification_service.dart';
import '../../shared/widgets/animated_background.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F17),
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: settingsAsync.when(
                    loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (_, __) => const Center(
                      child: Text('Failed to load settings',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    data: (settings) => ListView(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 40),
                      children: [
                        _buildStreakCard(settings),
                        const SizedBox(height: 20),
                        _buildNotificationsSection(context, ref, settings),
                        const SizedBox(height: 20),
                        _buildAccountSection(context, ref),
                        const SizedBox(height: 20),
                        _buildTestButton(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Settings',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Streak card ────────────────────────────────────────────────────────────

  Widget _buildStreakCard(NotificationSettings s) {
    final streak = s.streakCount;
    final emoji = streak == 0
        ? '💤'
        : streak < 3
            ? '🌱'
            : streak < 7
                ? '🔥'
                : streak < 30
                    ? '⚡'
                    : '🏆';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak == 0 ? 'No streak yet' : '$streak-day streak!',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streak == 0
                      ? 'Log a transaction today to start your streak'
                      : streak == 1
                          ? 'Log again tomorrow to build your streak'
                          : 'You\'ve logged transactions $streak days in a row!',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Notifications section ──────────────────────────────────────────────────

  Widget _buildNotificationsSection(
      BuildContext context, WidgetRef ref, NotificationSettings s) {
    return _Section(
      title: 'NOTIFICATIONS',
      children: [
        // Master toggle
        _ToggleTile(
          icon: Icons.notifications_rounded,
          iconColor: AppColors.primary,
          title: 'Enable notifications',
          subtitle: 'Master switch for all alerts',
          value: s.enabled,
          onChanged: (v) => _update(ref, s.copyWith(enabled: v)),
        ),
        if (s.enabled) ...[
          _Divider(),

          // Daily reminder
          _ToggleTile(
            icon: Icons.bedtime_rounded,
            iconColor: const Color(0xFF6C63FF),
            title: 'Daily reminder',
            subtitle: 'Remind me to log expenses',
            value: s.dailyReminder,
            onChanged: (v) => _update(ref, s.copyWith(dailyReminder: v)),
          ),
          if (s.dailyReminder)
            _TimeTile(
              label: 'Reminder time',
              hour: s.dailyHour,
              minute: s.dailyMinute,
              onChanged: (h, m) =>
                  _update(ref, s.copyWith(dailyHour: h, dailyMinute: m)),
              context: context,
            ),
          _Divider(),

          // Morning nudge
          _ToggleTile(
            icon: Icons.wb_sunny_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Morning nudge',
            subtitle: 'Log last night\'s expenses',
            value: s.morningNudge,
            onChanged: (v) => _update(ref, s.copyWith(morningNudge: v)),
          ),
          if (s.morningNudge)
            _TimeTile(
              label: 'Nudge time',
              hour: s.nudgeHour,
              minute: s.nudgeMinute,
              onChanged: (h, m) =>
                  _update(ref, s.copyWith(nudgeHour: h, nudgeMinute: m)),
              context: context,
            ),
          _Divider(),

          // Weekly summary
          _ToggleTile(
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF22C55E),
            title: 'Weekly summary',
            subtitle: 'Sunday evening recap',
            value: s.weeklyEnabled,
            onChanged: (v) => _update(ref, s.copyWith(weeklyEnabled: v)),
          ),
          _Divider(),

          // Streak
          _ToggleTile(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Streak notifications',
            subtitle: 'Celebrate your logging streak',
            value: s.streakEnabled,
            onChanged: (v) => _update(ref, s.copyWith(streakEnabled: v)),
          ),
        ],
      ],
    );
  }

  // ── Account section ────────────────────────────────────────────────────────

  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'ACCOUNT',
      children: [
        _ActionTile(
          icon: Icons.logout_rounded,
          iconColor: AppColors.expense,
          title: 'Sign out',
          subtitle: 'Clear saved password',
          onTap: () => _confirmSignOut(context, ref),
          danger: true,
        ),
      ],
    );
  }

  // ── Test button ────────────────────────────────────────────────────────────

  Widget _buildTestButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await NotificationService.instance.fireTest();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test notification sent!'),
              backgroundColor: AppColors.income,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'Send test notification',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _update(WidgetRef ref, NotificationSettings s) =>
      ref.read(settingsProvider.notifier).updateSettings(s);

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will clear your saved password. You\'ll need to enter it again to log in.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary.withOpacity(0.3)
                    : AppColors.surfaceHigh),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final int hour;
  final int minute;
  final void Function(int, int) onChanged;
  final BuildContext context;

  const _TimeTile({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
    required this.context,
  });

  String get _formatted {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surfaceHigh,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked.hour, picked.minute);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(66, 0, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                _formatted,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: danger
                              ? AppColors.expense
                              : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.border,
      );
}

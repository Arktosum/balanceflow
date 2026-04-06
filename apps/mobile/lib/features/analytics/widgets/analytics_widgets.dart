import 'package:flutter/material.dart';
import '../../../core/theme.dart';

// ── Tab bar ───────────────────────────────────────────────────────────────────

const analyticsTabLabels = ['Overview', 'Categories', 'Items', 'Merchants'];

class AnalyticsTabBar extends StatelessWidget {
  final int selected;
  final void Function(int) onChanged;

  const AnalyticsTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(analyticsTabLabels.length, (i) {
          final active = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: active
                      ? Border.all(color: AppColors.primary.withOpacity(0.4))
                      : null,
                ),
                child: Text(
                  analyticsTabLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Summary chips ─────────────────────────────────────────────────────────────

class SummaryChips extends StatelessWidget {
  final double income;
  final double expenses;
  final double net;
  final int txCount;

  const SummaryChips({
    super.key,
    required this.income,
    required this.expenses,
    required this.net,
    required this.txCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _Chip(
                    label: 'Income',
                    value: _fmt(income),
                    color: AppColors.income,
                    icon: Icons.arrow_downward_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _Chip(
                    label: 'Expenses',
                    value: _fmt(expenses),
                    color: AppColors.expense,
                    icon: Icons.arrow_upward_rounded)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _Chip(
                    label: 'Net',
                    value: '${net >= 0 ? '+' : ''}${_fmt(net)}',
                    color: net >= 0 ? AppColors.income : AppColors.expense,
                    icon: net >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _Chip(
                    label: 'Transactions',
                    value: '$txCount',
                    color: AppColors.primary,
                    icon: Icons.receipt_long_rounded)),
          ],
        ),
      ],
    );
  }

  String _fmt(double v) {
    // Short format for analytics chips: ₹1.2L, ₹45K
    final abs = v.abs();
    final prefix = v < 0 ? '-' : '';
    if (abs >= 100000) return '$prefix₹${(abs / 100000).toStringAsFixed(1)}L';
    if (abs >= 1000) return '$prefix₹${(abs / 1000).toStringAsFixed(1)}K';
    return '$prefix₹${abs.toStringAsFixed(0)}';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _Chip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class AnalyticsShimmer extends StatelessWidget {
  final double height;
  const AnalyticsShimmer({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

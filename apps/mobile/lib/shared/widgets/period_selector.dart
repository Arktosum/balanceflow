import 'package:flutter/material.dart';
import '../../../../../core/theme.dart';

enum Period { week, month, year, all, custom }

extension PeriodExt on Period {
  String get label => switch (this) {
        Period.week => 'Week',
        Period.month => 'Month',
        Period.year => 'Year',
        Period.all => 'All',
        Period.custom => 'Custom',
      };

  String get apiValue => switch (this) {
        Period.week => 'week',
        Period.month => 'month',
        Period.year => 'year',
        Period.all => 'all',
        Period.custom => 'custom',
      };
}

class PeriodSelector extends StatelessWidget {
  final Period selected;
  final DateTimeRange? customRange;
  final void Function(Period, DateTimeRange?) onChanged;
  final List<Period> periods;

  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.customRange,
    this.periods = Period.values,
  });

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
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
    if (range != null) onChanged(Period.custom, range);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) {
          final isSelected = selected == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (p == Period.custom) {
                  _pickCustom(context);
                } else {
                  onChanged(p, null);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  p == Period.custom && customRange != null && isSelected
                      ? _fmtRange(customRange!)
                      : p.label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _fmtRange(DateTimeRange r) {
    String fmt(DateTime d) =>
        '${d.day}/${d.month}/${d.year.toString().substring(2)}';
    return '${fmt(r.start)}–${fmt(r.end)}';
  }
}

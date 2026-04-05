import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';

class FilterPanel extends StatelessWidget {
  final String? filterType;
  final String? filterStatus;
  final String? filterAccountId;
  final List<Account> accounts;
  final void Function(String?) onTypeChanged;
  final void Function(String?) onStatusChanged;
  final void Function(String?) onAccountChanged;
  final VoidCallback onClearAll;

  const FilterPanel({
    super.key,
    required this.filterType,
    required this.filterStatus,
    required this.filterAccountId,
    required this.accounts,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onAccountChanged,
    required this.onClearAll,
  });

  bool get hasFilters =>
      filterType != null ||
      filterStatus != null ||
      filterAccountId != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterLabel('TYPE'),
          const SizedBox(height: 8),
          _ChipRow(
            options: const ['All', 'Expense', 'Income', 'Transfer'],
            selected: filterType == null
                ? 'All'
                : _cap(filterType!),
            onSelect: (v) =>
                onTypeChanged(v == 'All' ? null : v.toLowerCase()),
          ),
          const SizedBox(height: 12),
          _FilterLabel('STATUS'),
          const SizedBox(height: 8),
          _ChipRow(
            options: const ['All', 'Completed', 'Pending'],
            selected: filterStatus == null
                ? 'All'
                : _cap(filterStatus!),
            onSelect: (v) =>
                onStatusChanged(v == 'All' ? null : v.toLowerCase()),
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FilterLabel('ACCOUNT'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: filterAccountId == null,
                    onTap: () => onAccountChanged(null),
                  ),
                  ...accounts.map((a) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: a.name,
                          selected: filterAccountId == a.id,
                          onTap: () => onAccountChanged(a.id),
                        ),
                      )),
                ],
              ),
            ),
          ],
          if (hasFilters) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onClearAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.expense.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.expense.withOpacity(0.2)),
                ),
                child: const Text(
                  'Clear all filters',
                  style: TextStyle(
                    color: AppColors.expense,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );
}

class _ChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;

  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final first = o == options.first;
          return Padding(
            padding: EdgeInsets.only(left: first ? 0 : 8),
            child: _FilterChip(
              label: o,
              selected: selected == o,
              onTap: () => onSelect(o),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
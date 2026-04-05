import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class TypeSelector extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const TypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _types = [
    ('expense', '💸', 'Expense'),
    ('income', '💰', 'Income'),
    ('transfer', '🔄', 'Transfer'),
  ];

  Color _color(String type) => switch (type) {
        'income' => AppColors.income,
        'transfer' => AppColors.primary,
        _ => AppColors.expense,
      };

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
        children: _types.map((t) {
          final (value, emoji, label) = t;
          final active = selected == value;
          final color = _color(value);
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? color.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      active ? Border.all(color: color.withOpacity(0.4)) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: active ? color : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

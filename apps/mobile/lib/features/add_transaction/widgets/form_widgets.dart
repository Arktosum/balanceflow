import 'package:flutter/material.dart';
import '../../../core/theme.dart';

// ── Section card ──────────────────────────────────────────────────────────────

class FormCard extends StatelessWidget {
  final String title;
  final Widget child;

  const FormCard({super.key, required this.title, required this.child});

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
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Labelled row ──────────────────────────────────────────────────────────────

class FormRow extends StatelessWidget {
  final String label;
  final Widget child;

  const FormRow({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ── Tappable field box ────────────────────────────────────────────────────────

class FieldBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const FieldBox({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

// ── Status toggle ─────────────────────────────────────────────────────────────

class StatusToggle extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const StatusToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['completed', 'pending'].map((s) {
        final active = selected == s;
        final color =
            s == 'completed' ? AppColors.income : AppColors.pending;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? color.withOpacity(0.12)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? color.withOpacity(0.4)
                      : AppColors.border,
                ),
              ),
              child: Text(
                s[0].toUpperCase() + s.substring(1),
                style: TextStyle(
                  color: active ? color : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: active
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Account dropdown ──────────────────────────────────────────────────────────

class AccountDropdown extends StatelessWidget {
  final List<Map<String, String>> accounts;
  final String? value;
  final String hint;
  final void Function(String?) onChanged;

  const AccountDropdown({
    super.key,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.hint = 'Select account',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14)),
          dropdownColor: AppColors.surfaceHigh,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14),
          isExpanded: true,
          isDense: true,
          items: accounts
              .map((a) => DropdownMenuItem(
                    value: a['id'],
                    child: Text(a['name']!),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
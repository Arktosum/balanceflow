import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';

class TransactionCard extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.tx,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = parseHexColor(tx.categoryColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Category icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  tx.categoryIcon ?? tx.defaultEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchantName ?? tx.note ?? tx.type,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx.note != null && tx.merchantName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      tx.note!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 5),
                  _ChipsRow(tx: tx, catColor: catColor),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.amountPrefix}${fmtCurrency(tx.amount)}',
                  style: TextStyle(
                    color: tx.amountColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fmtTime(tx.date),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final Transaction tx;
  final Color catColor;

  const _ChipsRow({required this.tx, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        if (tx.categoryName != null)
          _Chip(label: tx.categoryName!, color: catColor),
        if (tx.accountName != null)
          _Chip(
              label: tx.accountName!,
              color: AppColors.textMuted,
              subtle: true),
        if (tx.itemCount > 0)
          _Chip(
              label:
                  '${tx.itemCount} item${tx.itemCount != 1 ? 's' : ''}',
              color: AppColors.textMuted,
              subtle: true),
        if (tx.status == 'pending')
          _Chip(label: 'pending', color: AppColors.pending),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool subtle;

  const _Chip({
    required this.label,
    required this.color,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: subtle
            ? AppColors.surfaceHigh
            : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: subtle ? AppColors.textMuted : color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
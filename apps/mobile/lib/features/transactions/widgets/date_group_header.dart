import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';

class DateGroupHeader extends StatelessWidget {
  final String dateLabel;
  final List<Transaction> transactions;

  const DateGroupHeader({
    super.key,
    required this.dateLabel,
    required this.transactions,
  });

  double get _dayNet => transactions.fold(0, (sum, tx) {
        if (tx.type == 'expense') return sum - tx.amount;
        if (tx.type == 'income') return sum + tx.amount;
        return sum;
      });

  @override
  Widget build(BuildContext context) {
    final net = _dayNet;
    final netColor = net >= 0 ? AppColors.income : AppColors.expense;
    final netLabel = '${net >= 0 ? '+' : ''}${fmtCurrency(net)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            dateLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: AppColors.border),
          ),
          const SizedBox(width: 10),
          Text(
            netLabel,
            style: TextStyle(
              color: netColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

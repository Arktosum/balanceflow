import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add Transaction',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      ),
      body: const Center(
        child: Text('Add Transaction', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

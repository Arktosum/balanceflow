import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Text('Accounts', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Text('Dashboard', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Text('Analytics', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

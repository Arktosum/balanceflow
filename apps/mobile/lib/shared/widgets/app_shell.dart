import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../features/add_transaction/add_transaction_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import 'animated_background.dart';

final _tabProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _screens = [
    DashboardScreen(),
    TransactionsScreen(),
    AccountsScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_tabProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AnimatedBackground(),
          IndexedStack(index: tab, children: _screens),
          Positioned(
            bottom: bottom + 12,
            left: 20,
            right: 20,
            child: _NavBar(
              tab: tab,
              onTabChanged: (i) => ref.read(_tabProvider.notifier).state = i,
              onAdd: () => Navigator.of(context).push(MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const AddTransactionScreen(),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int tab;
  final void Function(int) onTabChanged;
  final VoidCallback onAdd;

  const _NavBar({
    required this.tab,
    required this.onTabChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: tab == 0,
                  onTap: () => onTabChanged(0)),
              _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Transactions',
                  selected: tab == 1,
                  onTap: () => onTabChanged(1)),
              // Centre add button
              Expanded(
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF9C8FFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
              _NavItem(
                  icon: Icons.account_balance_rounded,
                  label: 'Accounts',
                  selected: tab == 2,
                  onTap: () => onTabChanged(2)),
              _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Analytics',
                  selected: tab == 3,
                  onTap: () => onTabChanged(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

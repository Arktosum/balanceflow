import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets/app_shell.dart';
import 'widgets/account_card.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _accountsProvider =
    FutureProvider.autoDispose<List<Account>>((ref) async {
  final raw = await ref.read(apiClientProvider).fetchAccounts();
  return raw
      .map((e) => Account.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _openTransactions(WidgetRef ref, String accountId) {
    // Pre-set the filter then switch to Transactions tab (index 1)
    ref.read(txAccountFilterProvider.notifier).state = accountId;
    ref.read(tabProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(_accountsProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceHigh,
          onRefresh: () async => ref.invalidate(_accountsProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _NetWorthCard(accounts: accounts),
                      const SizedBox(height: 24),
                      const Text(
                        'Your Accounts',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              accounts.when(
                loading: () => _buildShimmer(),
                error: (_, __) => const SliverToBoxAdapter(
                    child: SizedBox.shrink()),
                data: (list) {
                  if (list.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('🏦',
                                style: TextStyle(fontSize: 48)),
                            SizedBox(height: 16),
                            Text('No accounts yet',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(20, 12, 20, bottom + 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AccountCard(
                            account: list[i],
                            onTap: () => _openTransactions(
                                ref, list[i].id),
                          ),
                        ),
                        childCount: list.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Accounts',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }

  SliverList _buildShimmer() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => Container(
          height: 80,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        childCount: 3,
      ),
    );
  }
}

// ── Net worth card ────────────────────────────────────────────────────────────

class _NetWorthCard extends StatelessWidget {
  final AsyncValue<List<Account>> accounts;
  const _NetWorthCard({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final total =
            list.fold<double>(0, (s, a) => s + a.balance);
        final positiveCount =
            list.where((a) => a.balance >= 0).length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.18),
                AppColors.primary.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Net Worth',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fmtCurrency(total),
                style: TextStyle(
                  color: total >= 0
                      ? AppColors.textPrimary
                      : AppColors.expense,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              // Per-account type breakdown
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: _buildBreakdown(list),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildBreakdown(List<Account> list) {
    // Group by type, sum balances
    final byType = <String, double>{};
    for (final a in list) {
      byType[a.type] = (byType[a.type] ?? 0) + a.balance;
    }

    return byType.entries.map((e) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${e.key[0].toUpperCase()}${e.key.substring(1)}: ${fmtCurrency(e.value)}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      );
    }).toList();
  }
}
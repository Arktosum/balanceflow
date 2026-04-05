import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/models.dart';
import '../../shared/widgets/period_selector.dart';
import '../../shared/widgets/app_shell.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _accountsProvider = FutureProvider<List<Account>>((ref) async {
  final raw = await ref.read(apiClientProvider).fetchAccounts();
  return raw.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
});

final _dashPeriodProvider = StateProvider<Period>((ref) => Period.month);
final _dashCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final _summaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final period = ref.watch(_dashPeriodProvider);
  final custom = ref.watch(_dashCustomRangeProvider);
  final api = ref.read(apiClientProvider);
  return api.fetchAnalyticsSummary(
    period: period.apiValue,
    from: period == Period.custom ? custom?.start.toIso8601String() : null,
    to: period == Period.custom ? custom?.end.toIso8601String() : null,
  );
});

final _recentTxProvider =
    FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final raw = await ref.read(apiClientProvider).fetchTransactions(limit: 6);
  return raw
      .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(_accountsProvider);
    final summary = ref.watch(_summaryProvider);
    final recentTx = ref.watch(_recentTxProvider);
    final period = ref.watch(_dashPeriodProvider);
    final customRange = ref.watch(_dashCustomRangeProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceHigh,
          onRefresh: () async {
            ref.invalidate(_accountsProvider);
            ref.invalidate(_summaryProvider);
            ref.invalidate(_recentTxProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(),
                      const SizedBox(height: 20),
                      PeriodSelector(
                        selected: period,
                        customRange: customRange,
                        onChanged: (p, range) {
                          ref.read(_dashPeriodProvider.notifier).state = p;
                          ref
                              .read(_dashCustomRangeProvider.notifier)
                              .state = range;
                        },
                      ),
                      const SizedBox(height: 20),
                      _SummaryRow(summary: summary),
                      const SizedBox(height: 20),
                      _BalanceHero(accounts: accounts),
                      const SizedBox(height: 20),
                      _AccountsSection(accounts: accounts),
                      const SizedBox(height: 24),
                      _RecentHeader(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              _RecentTransactions(recentTx: recentTx),
              SliverToBoxAdapter(child: SizedBox(height: bottom + 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              const Text('BalanceFlow',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  )),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showSettings(context, ref),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.settings_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Settings',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.expense.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.expense, size: 18),
              ),
              title: const Text('Sign out',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Clear saved password',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return summary.when(
      loading: () => Row(
        children: List.generate(
          3,
          (_) => Expanded(
            child: Container(
              height: 72,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final income = toDouble(data['total_income']);
        final expense = toDouble(data['total_expenses']);
        final net = income - expense;
        return Row(
          children: [
            Expanded(
                child: _SummaryChip(
                    label: 'Income',
                    amount: income,
                    color: AppColors.income,
                    icon: Icons.arrow_downward_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _SummaryChip(
                    label: 'Expenses',
                    amount: expense,
                    color: AppColors.expense,
                    icon: Icons.arrow_upward_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _SummaryChip(
                    label: 'Net',
                    amount: net,
                    color: net >= 0 ? AppColors.income : AppColors.expense,
                    icon: net >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded)),
          ],
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _SummaryChip(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fmtCurrency(amount.abs()),
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Balance hero ──────────────────────────────────────────────────────────────

class _BalanceHero extends StatelessWidget {
  final AsyncValue<List<Account>> accounts;
  const _BalanceHero({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      loading: () => Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final total = list.fold<double>(0, (s, a) => s + a.balance);
        return Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
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
            border:
                Border.all(color: AppColors.primary.withOpacity(0.25)),
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
              const Text('Total Balance',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3)),
              const SizedBox(height: 8),
              Text(
                fmtCurrency(total),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'across ${list.length} account${list.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Accounts ──────────────────────────────────────────────────────────────────

class _AccountsSection extends StatelessWidget {
  final AsyncValue<List<Account>> accounts;
  const _AccountsSection({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Accounts',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        accounts.when(
          loading: () => SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Container(
                width: 160,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) => SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _AccountCard(account: list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final color = account.parsedColor;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(width: 4, color: color),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(account.typeIcon, size: 13, color: color),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          account.type.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    account.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fmtCurrency(account.balance),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Recent transactions ───────────────────────────────────────────────────────

class _RecentHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Recent',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        GestureDetector(
          onTap: () => ref.read(tabProvider.notifier).state = 1,
          child: const Text('View all',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final AsyncValue<List<Transaction>> recentTx;
  const _RecentTransactions({required this.recentTx});

  @override
  Widget build(BuildContext context) {
    return recentTx.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Container(
            height: 68,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          childCount: 4,
        ),
      ),
      error: (_, __) =>
          const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No transactions yet',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 14)),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _TxTile(tx: list[i]),
            ),
            childCount: list.length,
          ),
        );
      },
    );
  }
}

class _TxTile extends StatelessWidget {
  final Transaction tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final catColor = parseHexColor(tx.categoryColor);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(tx.categoryIcon ?? tx.defaultEmoji,
                  style: const TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchantName ?? tx.note ?? tx.type,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${fmtDate(tx.date)}  ·  ${fmtTime(tx.date)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
                if (tx.accountName != null)
                  Text(
                    tx.accountName!,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            '${tx.amountPrefix}${fmtCurrency(tx.amount)}',
            style: TextStyle(
                color: tx.amountColor,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
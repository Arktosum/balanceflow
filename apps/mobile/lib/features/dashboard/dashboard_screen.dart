import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _Account {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String? color;

  const _Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.color,
  });

  factory _Account.fromJson(Map<String, dynamic> j) => _Account(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        balance: _toDouble(j['balance']),
        color: j['color'] as String?,
      );
}

class _Summary {
  final double totalBalance;
  final double totalIncome;
  final double totalExpenses;
  final double netChange;

  const _Summary({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netChange,
  });

  factory _Summary.fromJson(Map<String, dynamic> j) => _Summary(
        totalBalance: _toDouble(j['total_balance']),
        totalIncome: _toDouble(j['total_income']),
        totalExpenses: _toDouble(j['total_expenses']),
        netChange: _toDouble(j['net_change']),
      );
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

// ---------------------------------------------------------------------------
// Quotes
// ---------------------------------------------------------------------------

const _quotes = [
  _Quote(
    'A budget is telling your money where to go instead of wondering where it went.',
    'Dave Ramsey',
  ),
  _Quote(
    'Financial freedom is available to those who learn about it and work for it.',
    'Robert Kiyosaki',
  ),
  _Quote(
    'Do not save what is left after spending, but spend what is left after saving.',
    'Warren Buffett',
  ),
  _Quote(
    'The secret to getting ahead is getting started.',
    'Mark Twain',
  ),
  _Quote(
    "It's not your salary that makes you rich, it's your spending habits.",
    'Charles Jaffe',
  ),
  _Quote(
    'Beware of little expenses. A small leak will sink a great ship.',
    'Benjamin Franklin',
  ),
  _Quote(
    'An investment in knowledge pays the best interest.',
    'Benjamin Franklin',
  ),
];

class _Quote {
  final String text;
  final String author;
  const _Quote(this.text, this.author);
}

_Quote get _dailyQuote {
  final index =
      (DateTime.now().millisecondsSinceEpoch ~/ 86400000) % _quotes.length;
  return _quotes[index];
}

// ---------------------------------------------------------------------------
// Period
// ---------------------------------------------------------------------------

enum _Period { day, week, month, year, custom }

extension _PeriodLabel on _Period {
  String get label => switch (this) {
        _Period.day => 'Day',
        _Period.week => 'Week',
        _Period.month => 'Month',
        _Period.year => 'Year',
        _Period.custom => 'Custom',
      };

  String get apiValue => switch (this) {
        _Period.day => 'day',
        _Period.week => 'week',
        _Period.month => 'month',
        _Period.year => 'year',
        _Period.custom => 'custom',
      };
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _Period _period = _Period.month;
  DateTimeRange? _customRange;

  List<_Account> _accounts = [];
  _Summary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.fetchAccounts(),
        api.fetchAnalyticsSummary(
          period: _period.apiValue,
          from: _customRange?.start,
          to: _customRange?.end,
        ),
      ]);
      setState(() {
        _accounts = (results[0] as List<dynamic>)
            .map((e) => _Account.fromJson(e as Map<String, dynamic>))
            .toList();
        _summary =
            _Summary.fromJson(results[1] as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load data';
        _loading = false;
      });
    }
  }

  Future<void> _fetchSummaryOnly() async {
    setState(() {
      _summary = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.fetchAnalyticsSummary(
        period: _period.apiValue,
        from: _customRange?.start,
        to: _customRange?.end,
      );
      setState(() => _summary = _Summary.fromJson(result));
    } catch (_) {}
  }

  Future<void> _onPeriodTap(_Period p) async {
    if (p == _Period.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customRange,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surfaceHigh,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        ),
      );
      if (range == null) return;
      setState(() {
        _period = _Period.custom;
        _customRange = range;
      });
    } else {
      setState(() {
        _period = p;
        _customRange = null;
      });
    }
    _fetchSummaryOnly();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _periodLabel {
    if (_period == _Period.custom && _customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${s.day} ${m[s.month - 1]} – ${e.day} ${m[e.month - 1]}';
    }
    return _period.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: _fetchAll,
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              sliver: SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _Header(
                      greeting: _greeting,
                      period: _period,
                      periodLabel: _periodLabel,
                      onPeriodTap: _onPeriodTap,
                    ),
                    const SizedBox(height: 20),
                    _QuoteCard(quote: _dailyQuote),
                    const SizedBox(height: 20),
                    _HeroBalanceCard(
                      balance: _summary?.totalBalance,
                      loading: _loading,
                    ),
                    const SizedBox(height: 16),
                    _StatRow(
                      summary: _summary,
                      loading: _loading,
                      periodLabel: _periodLabel,
                    ),
                    const SizedBox(height: 24),
                    _AccountsSection(
                      accounts: _accounts,
                      loading: _loading,
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String greeting;
  final _Period period;
  final String periodLabel;
  final void Function(_Period) onPeriodTap;

  const _Header({
    required this.greeting,
    required this.period,
    required this.periodLabel,
    required this.onPeriodTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, Arktos 👋',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Welcome back!',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _Period.values.map((p) {
              final selected = period == p;
              final label = p == _Period.custom && period == _Period.custom
                  ? periodLabel
                  : p.label;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onPeriodTap(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quote card
// ---------------------------------------------------------------------------

class _QuoteCard extends StatelessWidget {
  final _Quote quote;
  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
          top: BorderSide(color: AppColors.border, width: 1),
          right: BorderSide(color: AppColors.border, width: 1),
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${quote.text}"',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— ${quote.author}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero balance card
// ---------------------------------------------------------------------------

class _HeroBalanceCard extends StatelessWidget {
  final double? balance;
  final bool loading;
  const _HeroBalanceCard({required this.balance, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF0D1829)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          loading
              ? _Shimmer(width: 200, height: 52)
              : Text(
                  _formatCurrency(balance ?? 0),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                  ),
                ),
          const SizedBox(height: 8),
          const Text(
            'across all accounts',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat row
// ---------------------------------------------------------------------------

class _StatRow extends StatelessWidget {
  final _Summary? summary;
  final bool loading;
  final String periodLabel;

  const _StatRow({
    required this.summary,
    required this.loading,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatChip(
            label: 'Income',
            value: summary?.totalIncome,
            color: AppColors.income,
            icon: Icons.trending_up_rounded,
            period: periodLabel,
            loading: loading,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Expenses',
            value: summary?.totalExpenses,
            color: AppColors.expense,
            icon: Icons.trending_down_rounded,
            period: periodLabel,
            loading: loading,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Net Change',
            value: summary?.netChange,
            color: (summary?.netChange ?? 0) >= 0
                ? AppColors.income
                : AppColors.expense,
            icon: Icons.swap_horiz_rounded,
            period: periodLabel,
            loading: loading,
            showSign: true,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  final IconData icon;
  final String period;
  final bool loading;
  final bool showSign;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.period,
    required this.loading,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? 0;
    final prefix =
        showSign && displayValue >= 0 ? '+' : '';

    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          loading
              ? _Shimmer(width: 80, height: 28)
              : Text(
                  '$prefix${_formatCurrency(displayValue)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            period,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accounts section
// ---------------------------------------------------------------------------

class _AccountsSection extends StatelessWidget {
  final List<_Account> accounts;
  final bool loading;

  const _AccountsSection({
    required this.accounts,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accounts',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        loading
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _Shimmer(width: 160, height: 110),
                    ),
                  ),
                ),
              )
            : accounts.isEmpty
                ? _EmptyAccounts()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: accounts.map((a) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _AccountCard(account: a),
                        );
                      }).toList(),
                    ),
                  ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final _Account account;
  const _AccountCard({required this.account});

  Color get _color {
    final hex = account.color;
    if (hex == null) return AppColors.primary;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.type.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  account.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  _formatCurrency(account.balance),
                  style: TextStyle(
                    color: account.balance < 0
                        ? AppColors.expense
                        : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text(
          'No accounts yet',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer placeholder
// ---------------------------------------------------------------------------

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  const _Shimmer({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatCurrency(double v) {
  final abs = v.abs();
  final prefix = v < 0 ? '-' : '';
  if (abs >= 10000000) {
    return '${prefix}₹${(abs / 10000000).toStringAsFixed(2)}Cr';
  }
  if (abs >= 100000) {
    return '${prefix}₹${(abs / 100000).toStringAsFixed(2)}L';
  }
  if (abs >= 1000) {
    return '${prefix}₹${(abs / 1000).toStringAsFixed(1)}k';
  }
  return '${prefix}₹${abs.toStringAsFixed(2)}';
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';

// ---------------------------------------------------------------------------
// Models
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
// Currency — Indian format, always explicit, 2 decimal places
// ---------------------------------------------------------------------------

String _formatCurrency(double v) {
  final isNegative = v < 0;
  final abs = v.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];

  // Indian grouping: last 3 digits, then groups of 2
  String formatted;
  if (intPart.length <= 3) {
    formatted = intPart;
  } else {
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    formatted = '${buf.toString()},$last3';
  }

  return '${isNegative ? '-' : ''}₹$formatted.$decPart';
}

// ---------------------------------------------------------------------------
// Quotes
// ---------------------------------------------------------------------------

class _Quote {
  final String text;
  final String author;
  const _Quote(this.text, this.author);
}

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
  _Quote('The secret to getting ahead is getting started.', 'Mark Twain'),
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

_Quote get _dailyQuote =>
    _quotes[(DateTime.now().millisecondsSinceEpoch ~/ 86400000) %
        _quotes.length];

// ---------------------------------------------------------------------------
// Period
// ---------------------------------------------------------------------------

enum _Period { day, week, month, year, custom }

extension _PeriodX on _Period {
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
        _summary = _Summary.fromJson(results[1] as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchSummaryOnly() async {
    setState(() => _summary = null);
    try {
      final result = await ref
          .read(apiClientProvider)
          .fetchAnalyticsSummary(
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
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _periodLabel {
    if (_period == _Period.custom && _customRange != null) {
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final s = _customRange!.start;
      final e = _customRange!.end;
      return '${s.day} ${m[s.month - 1]} – ${e.day} ${m[e.month - 1]}';
    }
    return _period.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildQuoteCard(),
                    const SizedBox(height: 20),
                    _buildHeroCard(),
                    const SizedBox(height: 16),
                    _buildStatRow(),
                    const SizedBox(height: 28),
                    _buildAccountsSection(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Logo mark
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(18, 12),
                  painter: _PulsePainter(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BalanceFlow',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '$_greeting, Arktos 👋',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'Welcome back!',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        // Period selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _Period.values.map((p) {
              final selected = _period == p;
              final label = (p == _Period.custom && selected)
                  ? _periodLabel
                  : p.label;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _onPeriodTap(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
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

  // ---------------------------------------------------------------------------
  // Quote card — fixed: separate Stack-based left accent instead of Border()
  // ---------------------------------------------------------------------------

  Widget _buildQuoteCard() {
    final quote = _dailyQuote;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(height: 8),
                Text(
                  quote.text,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '— ${quote.author}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Left accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero balance card
  // ---------------------------------------------------------------------------

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E1060), const Color(0xFF0D1829)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary.withOpacity(0.7),
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Total Balance',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _loading
              ? _Shimmer(width: 220, height: 56)
              : Text(
                  _formatCurrency(_summary?.totalBalance ?? 0),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
          const SizedBox(height: 8),
          Text(
            'across ${_accounts.length} account${_accounts.length != 1 ? 's' : ''}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stat row
  // ---------------------------------------------------------------------------

  Widget _buildStatRow() {
    final net = _summary?.netChange ?? 0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatCard(
            label: 'Income',
            value: _summary?.totalIncome,
            color: AppColors.income,
            icon: Icons.trending_up_rounded,
            period: _periodLabel,
            loading: _loading,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Expenses',
            value: _summary?.totalExpenses,
            color: AppColors.expense,
            icon: Icons.trending_down_rounded,
            period: _periodLabel,
            loading: _loading,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Net Change',
            value: net,
            color: net >= 0 ? AppColors.income : AppColors.expense,
            icon: Icons.swap_horiz_rounded,
            period: _periodLabel,
            loading: _loading,
            showSign: true,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Accounts section
  // ---------------------------------------------------------------------------

  Widget _buildAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.credit_card_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              'Accounts',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _loading
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _Shimmer(width: 160, height: 120),
                    ),
                  ),
                ),
              )
            : _accounts.isEmpty
            ? Container(
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
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _accounts
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _AccountCard(account: a),
                        ),
                      )
                      .toList(),
                ),
              ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card widget
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  final IconData icon;
  final String period;
  final bool loading;
  final bool showSign;

  const _StatCard({
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
    final v = value ?? 0;
    final prefix = showSign && v >= 0 ? '+' : '';
    return Container(
      width: 160,
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
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          loading
              ? _Shimmer(width: 100, height: 22)
              : Text(
                  '$prefix${_formatCurrency(v)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            period,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account card widget
// ---------------------------------------------------------------------------

class _AccountCard extends StatelessWidget {
  final _Account account;
  const _AccountCard({required this.account});

  Color get _accentColor {
    final hex = account.color;
    if (hex == null) return AppColors.primary;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return AppColors.primary;
  }

  IconData get _typeIcon => switch (account.type.toLowerCase()) {
    'bank' => Icons.account_balance_rounded,
    'wallet' => Icons.account_balance_wallet_rounded,
    'cash' => Icons.payments_rounded,
    _ => Icons.credit_card_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    return Container(
      width: 168,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      account.type.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
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

// ---------------------------------------------------------------------------
// Shimmer placeholder
// ---------------------------------------------------------------------------

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  const _Shimmer({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

// ---------------------------------------------------------------------------
// Pulse logo painter
// ---------------------------------------------------------------------------

class _PulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final mid = h / 2;

    final path = Path()
      ..moveTo(0, mid)
      ..lineTo(w * 0.15, mid)
      ..lineTo(w * 0.15, mid - h * 0.4)
      ..lineTo(w * 0.38, mid - h * 0.4)
      ..lineTo(w * 0.38, mid)
      ..lineTo(w * 0.50, mid)
      ..lineTo(w * 0.50, mid + h * 0.4)
      ..lineTo(w * 0.73, mid + h * 0.4)
      ..lineTo(w * 0.73, mid)
      ..lineTo(w, mid);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

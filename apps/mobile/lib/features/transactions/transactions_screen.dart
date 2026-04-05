import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/models.dart';
import '../../shared/widgets/period_selector.dart';
import 'widgets/transaction_card.dart';
import 'widgets/filter_panel.dart';
import 'widgets/date_group_header.dart';
import 'transaction_detail_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  // Period
  Period _period = Period.month;
  DateTimeRange? _customRange;

  // Filters
  String? _filterType;
  String? _filterStatus;
  String? _filterAccountId;
  bool _showFilters = false;

  // Search (client-side)
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Data
  List<Transaction> _transactions = [];
  List<Account> _accounts = [];
  bool _loading = true;
  String? _error;

  bool get _hasFilters =>
      _filterType != null || _filterStatus != null || _filterAccountId != null;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.fetchTransactions(
          type: _filterType,
          status: _filterStatus,
          accountId: _filterAccountId,
          from: _periodFrom,
          to: _periodTo,
        ),
        api.fetchAccounts(),
      ]);
      setState(() {
        _transactions = (results[0] as List)
            .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList();
        _accounts = (results[1] as List)
            .map((e) => Account.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(apiClientProvider).fetchTransactions(
            type: _filterType,
            status: _filterStatus,
            accountId: _filterAccountId,
            from: _periodFrom,
            to: _periodTo,
          );
      setState(() {
        _transactions = raw
            .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? get _periodFrom {
    if (_period == Period.custom) {
      return _customRange?.start.toUtc().toIso8601String();
    }
    final now = DateTime.now();
    return switch (_period) {
      Period.week =>
        now.subtract(const Duration(days: 7)).toUtc().toIso8601String(),
      Period.month =>
        DateTime(now.year, now.month, 1).toUtc().toIso8601String(),
      Period.year => DateTime(now.year, 1, 1).toUtc().toIso8601String(),
      Period.all => null,
      _ => null,
    };
  }

  String? get _periodTo {
    if (_period == Period.custom) {
      return _customRange?.end.toUtc().toIso8601String();
    }
    return null;
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<Transaction> get _filtered {
    if (_search.trim().isEmpty) return _transactions;
    final q = _search.toLowerCase();
    return _transactions.where((tx) {
      return (tx.merchantName?.toLowerCase().contains(q) ?? false) ||
          (tx.note?.toLowerCase().contains(q) ?? false) ||
          (tx.categoryName?.toLowerCase().contains(q) ?? false) ||
          tx.amount.toString().contains(q);
    }).toList();
  }

  // Group filtered list by date label
  Map<String, List<Transaction>> get _grouped {
    final map = <String, List<Transaction>>{};
    for (final tx in _filtered) {
      final key = fmtDate(tx.date);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _clearFilters() {
    setState(() {
      _filterType = null;
      _filterStatus = null;
      _filterAccountId = null;
    });
    _fetchTransactions();
  }

  Future<void> _openDetail(Transaction tx) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(tx: tx),
      ),
    );
    if (result == 'updated' || result == 'deleted') {
      _fetchTransactions();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceHigh,
          onRefresh: _fetchAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSearchBar()),
              if (_showFilters)
                SliverToBoxAdapter(
                  child: FilterPanel(
                    filterType: _filterType,
                    filterStatus: _filterStatus,
                    filterAccountId: _filterAccountId,
                    accounts: _accounts,
                    onTypeChanged: (v) {
                      setState(() => _filterType = v);
                      _fetchTransactions();
                    },
                    onStatusChanged: (v) {
                      setState(() => _filterStatus = v);
                      _fetchTransactions();
                    },
                    onAccountChanged: (v) {
                      setState(() => _filterAccountId = v);
                      _fetchTransactions();
                    },
                    onClearAll: _clearFilters,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: PeriodSelector(
                    selected: _period,
                    customRange: _customRange,
                    periods: [
                      Period.week,
                      Period.month,
                      Period.year,
                      Period.all,
                      Period.custom,
                    ],
                    onChanged: (p, range) {
                      setState(() {
                        _period = p;
                        _customRange = range;
                      });
                      _fetchTransactions();
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (_loading)
                _buildShimmer()
              else if (_error != null)
                _buildError()
              else if (_filtered.isEmpty)
                _buildEmpty()
              else
                _buildList(),
              SliverToBoxAdapter(child: SizedBox(height: bottom + 100)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _loading
                      ? '...'
                      : '${_filtered.length} transaction${_filtered.length != 1 ? 's' : ''}',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _hasFilters
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasFilters
                      ? AppColors.primary.withOpacity(0.4)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 15,
                      color: _hasFilters
                          ? AppColors.primary
                          : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _hasFilters ? 'Filters •' : 'Filters',
                    style: TextStyle(
                      color: _hasFilters
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
              ),
            ),
            if (_search.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _search = '');
                },
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Transaction list ───────────────────────────────────────────────────────

  Widget _buildList() {
    final grouped = _grouped;
    final dates = grouped.keys.toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final date = dates[i];
            final txs = grouped[date]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateGroupHeader(dateLabel: date, transactions: txs),
                ...txs.map((tx) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransactionCard(
                        tx: tx,
                        onTap: () => _openDetail(tx),
                      ),
                    )),
              ],
            );
          },
          childCount: dates.length,
        ),
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Container(
            height: 72,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildError() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.textMuted, size: 40),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _fetchAll,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final msg = _search.isNotEmpty
        ? 'No results for "$_search"'
        : _hasFilters
            ? 'No transactions match filters'
            : 'No transactions this ${_period.label.toLowerCase()}';
    final sub = _search.isNotEmpty
        ? 'Try a different search term'
        : _hasFilters
            ? 'Try clearing some filters'
            : 'Tap + to add your first transaction';

    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(msg,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(sub,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import 'transaction_models.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  List<TxModel> _transactions = [];
  List<AccountModel> _accounts = [];
  List<MerchantModel> _merchants = [];
  bool _loading = true;
  String? _error;

  // Filters
  String _search = '';
  String? _filterType;
  String? _filterStatus;
  String? _filterAccountId;
  String? _filterMerchantId;
  bool _showFilters = false;

  // Merchant search in filter
  final _merchantSearchCtrl = TextEditingController();
  String _merchantFilterSearch = '';

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _merchantSearchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _filterType != null ||
      _filterStatus != null ||
      _filterAccountId != null ||
      _filterMerchantId != null;

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
          merchantId: _filterMerchantId,
        ),
        api.fetchAccounts(),
        api.fetchMerchants(),
      ]);
      setState(() {
        _transactions = (results[0] as List<dynamic>)
            .map((e) => TxModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _accounts = (results[1] as List<dynamic>)
            .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _merchants = (results[2] as List<dynamic>)
            .map((e) => MerchantModel.fromJson(e as Map<String, dynamic>))
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
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(apiClientProvider)
          .fetchTransactions(
            type: _filterType,
            status: _filterStatus,
            accountId: _filterAccountId,
            merchantId: _filterMerchantId,
          );
      setState(() {
        _transactions = list
            .map((e) => TxModel.fromJson(e as Map<String, dynamic>))
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

  List<TxModel> get _filtered {
    if (_search.trim().isEmpty) return _transactions;
    final q = _search.toLowerCase();
    return _transactions.where((tx) {
      return (tx.merchantName?.toLowerCase().contains(q) ?? false) ||
          (tx.note?.toLowerCase().contains(q) ?? false) ||
          tx.amount.toString().contains(q) ||
          (tx.categoryName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Map<String, List<TxModel>> get _grouped {
    final groups = <String, List<TxModel>>{};
    for (final tx in _filtered) {
      final key = formatDate(tx.date);
      groups.putIfAbsent(key, () => []).add(tx);
    }
    return groups;
  }

  void _clearFilters() {
    setState(() {
      _filterType = null;
      _filterStatus = null;
      _filterAccountId = null;
      _filterMerchantId = null;
      _merchantSearchCtrl.clear();
      _merchantFilterSearch = '';
    });
    _fetchTransactions();
  }

  void _openDetail(TxModel tx) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: tx)),
    );
    if (result == 'updated' || result == 'deleted') {
      _fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            if (_showFilters) _buildFilterPanel(),
            Expanded(
              child: _loading
                  ? _buildShimmer()
                  : _error != null
                  ? _buildError()
                  : _filtered.isEmpty
                  ? _buildEmpty()
                  : _buildList(bottomPadding),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter button
              GestureDetector(
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: _hasFilters
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
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
          const SizedBox(height: 14),
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search transactions...',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
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
                    onTap: () => setState(() => _search = ''),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter panel
  // ---------------------------------------------------------------------------

  Widget _buildFilterPanel() {
    final filteredMerchants = _merchantFilterSearch.isEmpty
        ? _merchants
        : _merchants
              .where(
                (m) => m.name.toLowerCase().contains(
                  _merchantFilterSearch.toLowerCase(),
                ),
              )
              .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type
          _FilterLabel('Type'),
          const SizedBox(height: 8),
          _ChipRow(
            options: const ['All', 'Expense', 'Income', 'Transfer'],
            selected: _filterType == null
                ? 'All'
                : _filterType![0].toUpperCase() + _filterType!.substring(1),
            onSelect: (v) {
              setState(() => _filterType = v == 'All' ? null : v.toLowerCase());
              _fetchTransactions();
            },
          ),
          const SizedBox(height: 14),

          // Status
          _FilterLabel('Status'),
          const SizedBox(height: 8),
          _ChipRow(
            options: const ['All', 'Completed', 'Pending'],
            selected: _filterStatus == null
                ? 'All'
                : _filterStatus![0].toUpperCase() + _filterStatus!.substring(1),
            onSelect: (v) {
              setState(
                () => _filterStatus = v == 'All' ? null : v.toLowerCase(),
              );
              _fetchTransactions();
            },
          ),
          const SizedBox(height: 14),

          // Account
          _FilterLabel('Account'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'All',
                  selected: _filterAccountId == null,
                  onTap: () {
                    setState(() => _filterAccountId = null);
                    _fetchTransactions();
                  },
                ),
                ..._accounts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Chip(
                      label: a.name,
                      selected: _filterAccountId == a.id,
                      onTap: () {
                        setState(() => _filterAccountId = a.id);
                        _fetchTransactions();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Merchant search
          _FilterLabel('Merchant'),
          const SizedBox(height: 8),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(
                  Icons.search_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _merchantSearchCtrl,
                    onChanged: (v) => setState(() => _merchantFilterSearch = v),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search merchant...',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                  ),
                ),
                if (_filterMerchantId != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterMerchantId = null;
                        _merchantSearchCtrl.clear();
                        _merchantFilterSearch = '';
                      });
                      _fetchTransactions();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (filteredMerchants.isNotEmpty && _merchantFilterSearch.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: filteredMerchants.take(5).map((m) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterMerchantId = m.id;
                        _merchantSearchCtrl.text = m.name;
                        _merchantFilterSearch = '';
                      });
                      _fetchTransactions();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        m.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Clear all
          if (_hasFilters) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.expense.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.expense.withOpacity(0.2)),
                ),
                child: const Text(
                  'Clear all filters',
                  style: TextStyle(
                    color: AppColors.expense,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Transaction list
  // ---------------------------------------------------------------------------

  Widget _buildList(double bottomPadding) {
    final grouped = _grouped;
    final dates = grouped.keys.toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceHigh,
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 90),
        itemCount: dates.length,
        itemBuilder: (_, i) {
          final date = dates[i];
          final txs = grouped[date]!;
          final dayNet = txs.fold<double>(0, (sum, tx) {
            if (tx.type == 'expense') return sum - tx.amount;
            if (tx.type == 'income') return sum + tx.amount;
            return sum;
          });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(height: 1, color: AppColors.border),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatCurrency(dayNet),
                      style: TextStyle(
                        color: dayNet >= 0
                            ? AppColors.income
                            : AppColors.expense,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Transaction cards
              ...txs.map(
                (tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TxCard(tx: tx, onTap: () => _openDetail(tx)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // States
  // ---------------------------------------------------------------------------

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetchAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💸', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty
                ? 'No results for "$_search"'
                : _hasFilters
                ? 'No transactions match filters'
                : 'No transactions yet',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _search.isNotEmpty
                ? 'Try a different search term'
                : 'Tap + to add your first transaction',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transaction card
// ---------------------------------------------------------------------------

class _TxCard extends StatelessWidget {
  final TxModel tx;
  final VoidCallback onTap;
  const _TxCard({required this.tx, required this.onTap});

  Color get _amountColor => switch (tx.type) {
    'income' => AppColors.income,
    'transfer' => AppColors.primary,
    _ => AppColors.expense,
  };

  String get _amountPrefix => switch (tx.type) {
    'income' => '+',
    'expense' => '−',
    _ => '',
  };

  String get _defaultEmoji => switch (tx.type) {
    'income' => '💰',
    'transfer' => '🔄',
    _ => '💸',
  };

  Color _parseCategoryColor() {
    final hex = tx.categoryColor;
    if (hex == null) return AppColors.primary;
    final c = hex.replaceFirst('#', '');
    if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _parseCategoryColor();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  tx.categoryIcon ?? _defaultEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchantName ?? tx.note ?? tx.type,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx.note != null && tx.merchantName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tx.note!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (tx.categoryName != null)
                        _Badge(label: tx.categoryName!, color: catColor),
                      if (tx.accountName != null)
                        _Badge(
                          label: tx.accountName!,
                          color: AppColors.textMuted,
                          subtle: true,
                        ),
                      if (tx.itemCount > 0)
                        _Badge(
                          label:
                              '${tx.itemCount} item${tx.itemCount != 1 ? 's' : ''}',
                          color: AppColors.textMuted,
                          subtle: true,
                        ),
                      if (tx.status == 'pending')
                        _Badge(label: 'pending', color: AppColors.pending),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_amountPrefix${formatCurrency(tx.amount)}',
                  style: TextStyle(
                    color: _amountColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatTime(tx.date),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small badge
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool subtle;
  const _Badge({required this.label, required this.color, this.subtle = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: subtle ? AppColors.surfaceHigh : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: subtle ? AppColors.textMuted : color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter helpers
// ---------------------------------------------------------------------------

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );
}

class _ChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;
  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final isFirst = o == options.first;
          return Padding(
            padding: EdgeInsets.only(left: isFirst ? 0 : 8),
            child: _Chip(
              label: o,
              selected: selected == o,
              onTap: () => onSelect(o),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formatters
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/animated_background.dart';
import 'transaction_models.dart';

// ---------------------------------------------------------------------------
// Local models (detail-screen only)
// ---------------------------------------------------------------------------

class _TxItem {
  final String id;
  final String itemId;
  final String itemName;
  double amount;
  double quantity;
  String remarks;

  _TxItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.amount,
    required this.quantity,
    required this.remarks,
  });

  factory _TxItem.fromJson(Map<String, dynamic> j) => _TxItem(
    id: j['id'] as String? ?? '',
    itemId: j['item_id'] as String,
    itemName: j['item_name'] as String,
    amount: toDouble(j['amount']),
    quantity: toDouble(j['quantity']),
    remarks: j['remarks'] as String? ?? '',
  );

  double get subtotal => amount * quantity;
}

class _ItemSuggestion {
  final String id;
  final String name;
  final double lastPrice;
  const _ItemSuggestion({
    required this.id,
    required this.name,
    required this.lastPrice,
  });
  factory _ItemSuggestion.fromJson(Map<String, dynamic> j) => _ItemSuggestion(
    id: j['id'] as String,
    name: j['name'] as String,
    lastPrice: toDouble(j['last_price']),
  );
}

class _CategoryOption {
  final String id;
  final String name;
  final String? icon;
  const _CategoryOption({required this.id, required this.name, this.icon});
  factory _CategoryOption.fromJson(Map<String, dynamic> j) => _CategoryOption(
    id: j['id'] as String,
    name: j['name'] as String,
    icon: j['icon'] as String?,
  );
}

class _AccountOption {
  final String id;
  final String name;
  const _AccountOption({required this.id, required this.name});
  factory _AccountOption.fromJson(Map<String, dynamic> j) =>
      _AccountOption(id: j['id'] as String, name: j['name'] as String);
}

class _MerchantOption {
  final String id;
  final String name;
  const _MerchantOption({required this.id, required this.name});
  factory _MerchantOption.fromJson(Map<String, dynamic> j) =>
      _MerchantOption(id: j['id'] as String, name: j['name'] as String);
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final TxModel tx;
  const TransactionDetailScreen({super.key, required this.tx});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;
  bool _confirmDelete = false;
  bool _loadingItems = true;

  // Items
  List<_TxItem> _items = [];
  List<String> _removedItemIds = [];
  List<_ItemSuggestion> _allItems = [];
  final _itemSearchCtrl = TextEditingController();
  List<_ItemSuggestion> _itemSuggestions = [];
  final _itemFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // Edit fields
  late String _note;
  late String _categoryId;
  late String _accountId;
  late String _merchantName;
  late DateTime _date;

  // Options
  List<_CategoryOption> _categories = [];
  List<_AccountOption> _accounts = [];
  List<_MerchantOption> _merchants = [];
  List<_MerchantOption> _merchantSuggestions = [];
  final _merchantCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _note = widget.tx.note ?? '';
    _categoryId = widget.tx.categoryId ?? '';
    _accountId = widget.tx.accountId;
    _merchantName = widget.tx.merchantName ?? '';
    _date = widget.tx.date;
    _merchantCtrl.text = _merchantName;
    _loadData();
  }

  @override
  void dispose() {
    _removeOverlay();
    _itemSearchCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showItemOverlay() {
    _removeOverlay();
    if (_itemSuggestions.isEmpty) return;
    final box = _itemFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final suggestions = List<_ItemSuggestion>.from(_itemSuggestions);
    final searchText = _itemSearchCtrl.text.trim();
    final hasCreate =
        searchText.isNotEmpty &&
        !_allItems.any((i) => i.name.toLowerCase() == searchText.toLowerCase());

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...suggestions.map(
                  (s) => InkWell(
                    onTap: () {
                      _addItem(s);
                      _removeOverlay();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          if (s.lastPrice > 0)
                            Text(
                              formatCurrency(s.lastPrice),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasCreate)
                  InkWell(
                    onTap: () {
                      _createAndAddItem(searchText);
                      _removeOverlay();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text(
                        '+ Create "$searchText"',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onItemSearch(String v) {
    setState(() {
      _itemSuggestions = v.isEmpty
          ? []
          : _allItems
                .where((i) => i.name.toLowerCase().contains(v.toLowerCase()))
                .take(6)
                .toList();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showItemOverlay());
  }

  void _addItem(_ItemSuggestion suggestion) {
    setState(() {
      _items.add(
        _TxItem(
          id: '',
          itemId: suggestion.id,
          itemName: suggestion.name,
          amount: suggestion.lastPrice,
          quantity: 1,
          remarks: '',
        ),
      );
      _itemSearchCtrl.clear();
      _itemSuggestions = [];
    });
    _removeOverlay();
  }

  Future<void> _createAndAddItem(String name) async {
    try {
      final data = await ref.read(apiClientProvider).createItem(name);
      final suggestion = _ItemSuggestion(
        id: data['id'] as String,
        name: data['name'] as String,
        lastPrice: 0,
      );
      _addItem(suggestion);
    } catch (_) {}
  }

  void _removeItem(_TxItem item) {
    setState(() {
      if (item.id.isNotEmpty) _removedItemIds.add(item.id);
      _items.remove(item);
    });
  }

  double get _derivedTotal => _items.fold(0, (sum, i) => sum + i.subtotal);

  double get _displayAmount =>
      _items.isNotEmpty ? _derivedTotal : widget.tx.amount;

  // ---------------------------------------------------------------------------
  // Merchant autocomplete
  // ---------------------------------------------------------------------------

  void _onMerchantChanged(String v) {
    _merchantName = v;
    setState(() {
      _merchantSuggestions = v.isEmpty
          ? []
          : _merchants
                .where((m) => m.name.toLowerCase().contains(v.toLowerCase()))
                .take(5)
                .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);

      // Resolve merchant
      String? merchantId;
      final name = _merchantName.trim();
      if (name.isNotEmpty) {
        final existing = _merchants
            .where((m) => m.name.toLowerCase() == name.toLowerCase())
            .firstOrNull;
        if (existing != null) {
          merchantId = existing.id;
        } else {
          final created = await api.createMerchant(name);
          merchantId = created['id'] as String;
        }
      }

      final derivedAmount = _items.isNotEmpty
          ? _derivedTotal
          : widget.tx.amount;

      await api.updateTransaction(widget.tx.id, {
        'note': _note.isEmpty ? null : _note,
        'category_id': _categoryId.isEmpty ? null : _categoryId,
        'account_id': _accountId,
        'merchant_id': merchantId,
        'amount': derivedAmount,
        'date': _date.toIso8601String(),
      });

      // Delete removed items
      await Future.wait(
        _removedItemIds.map((id) => api.deleteTransactionItem(id)),
      );

      // Update existing items
      await Future.wait(
        _items
            .where((i) => i.id.isNotEmpty)
            .map(
              (i) => api.updateTransactionItem(i.id, {
                'amount': i.amount,
                'quantity': i.quantity,
                'remarks': i.remarks.isEmpty ? null : i.remarks,
              }),
            ),
      );

      // Add new items
      await Future.wait(
        _items
            .where((i) => i.id.isEmpty)
            .map(
              (i) => api.addTransactionItem(widget.tx.id, {
                'item_id': i.itemId,
                'amount': i.amount,
                'quantity': i.quantity,
                'remarks': i.remarks.isEmpty ? null : i.remarks,
              }),
            ),
      );

      if (mounted) {
        _showSnackbar('Transaction updated ✓', success: true);
        setState(() {
          _editing = false;
          _saving = false;
        });
        Navigator.of(context).pop('updated');
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to update: $e');
        setState(() => _saving = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).deleteTransaction(widget.tx.id);
      if (mounted) {
        _showSnackbar('Transaction deleted', success: true);
        Navigator.of(context).pop('deleted');
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to delete: $e');
        setState(() {
          _deleting = false;
          _confirmDelete = false;
        });
      }
    }
  }

  void _showSnackbar(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: success ? AppColors.income : AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Color get _amountColor => switch (widget.tx.type) {
    'income' => AppColors.income,
    'transfer' => AppColors.primary,
    _ => AppColors.expense,
  };

  String get _amountPrefix => switch (widget.tx.type) {
    'income' => '+',
    'expense' => '−',
    _ => '',
  };

  String get _defaultEmoji => switch (widget.tx.type) {
    'income' => '💰',
    'transfer' => '🔄',
    _ => '💸',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAmountHero(),
                        const SizedBox(height: 20),
                        if (!_loadingItems && (_items.isNotEmpty || _editing))
                          _buildItemsSection(),
                        if (!_loadingItems && (_items.isNotEmpty || _editing))
                          const SizedBox(height: 20),
                        _buildDetailsSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.tx.categoryIcon ?? _defaultEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tx.merchantName ?? widget.tx.note ?? 'Transaction',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.tx.type[0].toUpperCase() + widget.tx.type.substring(1),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Amount hero
  // ---------------------------------------------------------------------------

  Widget _buildAmountHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_amountColor.withOpacity(0.12), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _amountColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$_amountPrefix${formatCurrency(_displayAmount)}',
            style: TextStyle(
              color: _amountColor,
              fontSize: 42,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.tx.accountName ?? '',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (widget.tx.toAccountName != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  widget.tx.toAccountName!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.tx.status == 'completed'
                      ? AppColors.income.withOpacity(0.1)
                      : AppColors.pending.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.tx.status,
                  style: TextStyle(
                    color: widget.tx.status == 'completed'
                        ? AppColors.income
                        : AppColors.pending,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatDate(widget.tx.date)} at ${formatTime(widget.tx.date)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Items section
  // ---------------------------------------------------------------------------

  Widget _buildItemsSection() {
    return _Section(
      title: 'ITEMS',
      trailing: _items.isNotEmpty
          ? '${_items.length} item${_items.length != 1 ? "s" : ""}'
          : null,
      child: Column(
        children: [
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ItemRow(
                item: item,
                editing: _editing,
                onUpdate: (field, value) => setState(() {
                  if (field == 'amount') item.amount = value;
                  if (field == 'quantity') item.quantity = value;
                  if (field == 'remarks') item.remarks = value;
                }),
                onRemove: () => _removeItem(item),
              ),
            ),
          ),

          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    formatCurrency(_derivedTotal),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          if (_editing) ...[
            const SizedBox(height: 8),
            Container(
              key: _itemFieldKey,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _itemSearchCtrl,
                      onChanged: _onItemSearch,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Add item...',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        filled: false,
                      ),
                      onSubmitted: (v) async {
                        if (v.trim().isEmpty) return;
                        final match = _allItems.firstWhereOrNull(
                          (i) => i.name.toLowerCase() == v.toLowerCase(),
                        );
                        if (match != null) {
                          _addItem(match);
                        } else {
                          await _createAndAddItem(v.trim());
                        }
                        _itemSearchCtrl.clear();
                        setState(() => _itemSuggestions = []);
                        _removeOverlay();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return _Section(
      title: 'DETAILS',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailField(
                  label: 'DATE',
                  editing: _editing,
                  value:
                      '${formatDate(widget.tx.date)}\n${formatTime(widget.tx.date)}',
                  editChild: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
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
                      if (picked != null) {
                        setState(
                          () => _date = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            _date.hour,
                            _date.minute,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        formatDate(_date),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailField(
                  label: 'CATEGORY',
                  editing: _editing,
                  value: widget.tx.categoryName != null
                      ? '${widget.tx.categoryIcon ?? ''} ${widget.tx.categoryName}'
                      : '—',
                  editChild: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categoryId.isEmpty ? null : _categoryId,
                        hint: const Text(
                          'None',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        dropdownColor: AppColors.surfaceHigh,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        isExpanded: true,
                        isDense: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'None',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          ..._categories.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                '${c.icon ?? ''} ${c.name}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v ?? ''),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailField(
                  label: 'ACCOUNT',
                  editing: _editing,
                  value: widget.tx.accountName ?? '—',
                  editChild: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _accountId,
                        dropdownColor: AppColors.surfaceHigh,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        isExpanded: true,
                        isDense: true,
                        items: _accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  a.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _accountId = v ?? _accountId),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailField(
                  label: 'MERCHANT',
                  editing: _editing,
                  value: widget.tx.merchantName ?? '—',
                  editChild: Column(
                    children: [
                      TextField(
                        controller: _merchantCtrl,
                        onChanged: _onMerchantChanged,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Swiggy',
                          hintStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceHigh,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          isDense: true,
                        ),
                      ),
                      if (_merchantSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: _merchantSuggestions
                                .map(
                                  (m) => GestureDetector(
                                    onTap: () => setState(() {
                                      _merchantName = m.name;
                                      _merchantCtrl.text = m.name;
                                      _merchantSuggestions = [];
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      child: Text(
                                        m.name,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailField(
            label: 'NOTE',
            editing: _editing,
            value: widget.tx.note?.isNotEmpty == true ? widget.tx.note! : '—',
            editChild: TextField(
              onChanged: (v) => _note = v,
              controller: TextEditingController(text: _note),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Add a note...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: Color(0xCC0F1117),
      ),
      child: _confirmDelete
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Are you sure? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FooterButton(
                        label: 'Cancel',
                        onTap: () => setState(() => _confirmDelete = false),
                        subtle: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FooterButton(
                        label: _deleting ? 'Deleting...' : 'Yes, Delete',
                        onTap: _deleting ? null : _delete,
                        danger: true,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : _editing
          ? Row(
              children: [
                Expanded(
                  child: _FooterButton(
                    label: 'Cancel',
                    onTap: () => setState(() => _editing = false),
                    subtle: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FooterButton(
                    label: _saving ? 'Saving...' : 'Save Changes',
                    onTap: _saving ? null : _save,
                    primary: true,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _FooterButton(
                    label: 'Edit Transaction',
                    onTap: () => setState(() => _editing = true),
                    primary: true,
                    outline: true,
                  ),
                ),
                const SizedBox(width: 12),
                _FooterButton(
                  icon: Icons.delete_outline_rounded,
                  onTap: () => setState(() => _confirmDelete = true),
                  danger: true,
                  compact: true,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item row widget
// ---------------------------------------------------------------------------

class _ItemRow extends StatefulWidget {
  final _TxItem item;
  final bool editing;
  final void Function(String, dynamic) onUpdate;
  final VoidCallback onRemove;

  const _ItemRow({
    required this.item,
    required this.editing,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _remarksCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.item.amount.toStringAsFixed(2),
    );
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
    _remarksCtrl = TextEditingController(text: widget.item.remarks);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _qtyCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.itemName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatCurrency(widget.item.subtotal),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.editing) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ],
          ),
          if (widget.editing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniField(
                    controller: _amountCtrl,
                    prefix: '₹',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        widget.onUpdate('amount', double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniField(
                    controller: _qtyCtrl,
                    prefix: '×',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        widget.onUpdate('quantity', double.tryParse(v) ?? 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniField(
                    controller: _remarksCtrl,
                    hint: 'Note',
                    onChanged: (v) => widget.onUpdate('remarks', v),
                  ),
                ),
              ],
            ),
          ] else if (widget.item.quantity > 1 ||
              widget.item.remarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (widget.item.quantity > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '× ${widget.item.quantity.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${formatCurrency(widget.item.amount)} each',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (widget.item.remarks.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.item.remarks,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _Section({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final bool editing;
  final Widget? editChild;

  const _DetailField({
    required this.label,
    required this.value,
    required this.editing,
    this.editChild,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        editing && editChild != null
            ? editChild!
            : Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
      ],
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String? prefix;
  final String? hint;
  final TextInputType? keyboardType;
  final void Function(String) onChanged;

  const _MiniField({
    required this.controller,
    this.prefix,
    this.hint,
    this.keyboardType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (prefix != null)
            Text(
              prefix!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          if (prefix != null) const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
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
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool subtle;
  final bool danger;
  final bool outline;
  final bool compact;

  const _FooterButton({
    this.label,
    this.icon,
    this.onTap,
    this.primary = false,
    this.subtle = false,
    this.danger = false,
    this.outline = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;

    if (danger) {
      bgColor = AppColors.expense.withOpacity(0.1);
      textColor = AppColors.expense;
    } else if (primary && !outline) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else if (primary && outline) {
      bgColor = AppColors.primary.withOpacity(0.1);
      textColor = AppColors.primary;
      border = Border.all(color: AppColors.primary.withOpacity(0.3));
    } else if (subtle) {
      bgColor = AppColors.surfaceHigh;
      textColor = AppColors.textSecondary;
    } else {
      bgColor = AppColors.surfaceHigh;
      textColor = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: compact
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: border,
        ),
        child: icon != null
            ? Icon(icon, color: textColor, size: 18)
            : Center(
                child: Text(
                  label ?? '',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}

extension _ListX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/models.dart';
import '../../shared/widgets/animated_background.dart';
import '../../shared/widgets/overlay_autocomplete.dart';
import '../add_transaction/widgets/category_picker.dart';
import '../add_transaction/widgets/form_widgets.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final Transaction tx;
  const TransactionDetailScreen({super.key, required this.tx});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  // Mode
  bool _editing = false;
  bool _saving = false;
  bool _confirmDelete = false;
  bool _loadingItems = true;

  // Items
  List<TxItem> _items = [];
  List<String> _removedItemIds = [];
  List<ItemSuggestion> _allItems = [];
  final _itemSearchCtrl = TextEditingController();
  List<ItemSuggestion> _itemSuggestions = [];

  // Edit fields — initialised from tx
  late String _note;
  late String _categoryId;
  late String _accountId;
  late String _merchantName;
  late DateTime _date;
  late String _status;

  // Options
  List<Category> _categories = [];
  List<Account> _accounts = [];
  List<Merchant> _merchants = [];
  List<Merchant> _merchantSuggestions = [];
  final _merchantCtrl = TextEditingController();

  double get _derivedTotal => _items.fold(0, (s, i) => s + i.subtotal);

  double get _displayAmount =>
      _items.isNotEmpty ? _derivedTotal : widget.tx.amount;

  @override
  void initState() {
    super.initState();
    _note = widget.tx.note ?? '';
    _categoryId = widget.tx.categoryId ?? '';
    _accountId = widget.tx.accountId;
    _merchantName = widget.tx.merchantName ?? '';
    _date = widget.tx.date;
    _status = widget.tx.status;
    _merchantCtrl.text = _merchantName;
    _loadData();
  }

  @override
  void dispose() {
    _itemSearchCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.fetchTransactionItems(widget.tx.id),
        api.fetchItems(),
        api.fetchAccounts(),
        api.fetchMerchants(),
        api.fetchCategories(),
      ]);
      setState(() {
        _items = (results[0] as List)
            .map((e) => TxItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _allItems = (results[1] as List)
            .map((e) => ItemSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
        _accounts = (results[2] as List)
            .map((e) => Account.fromJson(e as Map<String, dynamic>))
            .toList();
        _merchants = (results[3] as List)
            .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
            .toList();
        _categories = (results[4] as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingItems = false;
      });
    } catch (_) {
      setState(() => _loadingItems = false);
    }
  }

  // ── Item helpers ───────────────────────────────────────────────────────────

  void _onItemSearch(String v) {
    setState(() {
      _itemSuggestions = v.isEmpty
          ? []
          : _allItems
              .where((i) => i.name.toLowerCase().contains(v.toLowerCase()))
              .take(6)
              .toList();
    });
  }

  void _addItem(ItemSuggestion s) {
    setState(() {
      _items.add(TxItem(
        id: '',
        itemId: s.id,
        itemName: s.name,
        amount: s.lastPrice,
        quantity: 1,
      ));
      _itemSearchCtrl.clear();
      _itemSuggestions = [];
    });
  }

  Future<void> _createAndAddItem(String name) async {
    try {
      final data = await ref.read(apiClientProvider).createItem(name);
      _addItem(ItemSuggestion.fromJson(data));
    } catch (_) {}
  }

  void _removeItem(TxItem item) {
    setState(() {
      if (item.id.isNotEmpty) _removedItemIds.add(item.id);
      _items.remove(item);
    });
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);

      // Resolve merchant
      String? merchantId;
      final mName = _merchantName.trim();
      if (mName.isNotEmpty && widget.tx.type != 'transfer') {
        final existing = _merchants.firstWhereOrNull(
            (m) => m.name.toLowerCase() == mName.toLowerCase());
        merchantId = existing?.id;
        if (merchantId == null) {
          final created = await api.createMerchant(mName);
          merchantId = created['id'] as String;
        }
      }

      await api.updateTransaction(widget.tx.id, {
        'note': _note.trim().isEmpty ? null : _note.trim(),
        'category_id': _categoryId.isEmpty ? null : _categoryId,
        'account_id': _accountId,
        'merchant_id': merchantId,
        'date': _date.toUtc().toIso8601String(),
        'status': _status,
        if (_items.isNotEmpty) 'amount': _derivedTotal,
      });

      // Remove deleted items
      await Future.wait(
          _removedItemIds.map((id) => api.deleteTransactionItem(id)));

      // Update existing items
      await Future.wait(_items.where((i) => i.id.isNotEmpty).map((i) {
        final payload = <String, dynamic>{
          'amount': i.amount,
          'quantity': i.quantity,
        };
        if (i.remarks.isNotEmpty) payload['remarks'] = i.remarks;
        return api.updateTransactionItem(i.id, payload);
      }));

      // Add new items
      await Future.wait(_items
          .where((i) => i.id.isEmpty)
          .map((i) => api.addTransactionItem(widget.tx.id, {
                'item_id': i.itemId,
                'amount': i.amount,
                'quantity': i.quantity,
                if (i.remarks.isNotEmpty) 'remarks': i.remarks,
              })));

      if (mounted) {
        _showSnack('Transaction updated ✓', success: true);
        setState(() {
          _editing = false;
          _saving = false;
        });
        Navigator.of(context).pop('updated');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e');
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    try {
      await ref.read(apiClientProvider).deleteTransaction(widget.tx.id);
      if (mounted) {
        _showSnack('Transaction deleted', success: true);
        Navigator.of(context).pop('deleted');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e');
        setState(() => _confirmDelete = false);
      }
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.income : AppColors.expense,
    ));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => _pickerTheme(ctx, child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      builder: (ctx, child) => _pickerTheme(ctx, child!),
    );
    final t = time ?? TimeOfDay.fromDateTime(_date);
    setState(() =>
        _date = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Widget _pickerTheme(BuildContext ctx, Widget child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surfaceHigh,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child,
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F17),
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 100),
                    child: Column(
                      children: [
                        _buildAmountHero(),
                        const SizedBox(height: 20),
                        if (!_loadingItems) _buildItemsSection(),
                        if (!_loadingItems) const SizedBox(height: 20),
                        _buildDetailsSection(),
                      ],
                    ),
                  ),
                ),
                _buildFooter(bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.tx.amountColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.tx.categoryIcon ?? widget.tx.defaultEmoji,
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
                      color: AppColors.textSecondary, fontSize: 12),
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
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount hero ────────────────────────────────────────────────────────────

  Widget _buildAmountHero() {
    final color = widget.tx.amountColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '${widget.tx.amountPrefix}${fmtCurrency(_displayAmount)}',
            style: TextStyle(
              color: color,
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
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              if (widget.tx.toAccountName != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 13, color: AppColors.textMuted),
                ),
                Text(widget.tx.toAccountName!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(width: 8),
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
            fmtDateTime(widget.tx.date),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Items section ──────────────────────────────────────────────────────────

  Widget _buildItemsSection() {
    if (_items.isEmpty && !_editing) return const SizedBox.shrink();

    return FormCard(
      title: 'ITEMS${_items.isNotEmpty ? ' · ${_items.length}' : ''}',
      child: Column(
        children: [
          ..._items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ItemRow(
                  item: item,
                  editing: _editing,
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeItem(item),
                ),
              )),
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  Text(fmtCurrency(_derivedTotal),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          if (_editing) ...[
            const SizedBox(height: 8),
            OverlayAutocomplete<ItemSuggestion>(
              controller: _itemSearchCtrl,
              hint: 'Add item...',
              suggestions: _itemSuggestions,
              labelOf: (s) => s.name,
              subtitleOf: (s) =>
                  s.lastPrice > 0 ? fmtCurrency(s.lastPrice) : null,
              onChanged: _onItemSearch,
              onSelect: _addItem,
              createLabel: _itemSearchCtrl.text.trim().isNotEmpty &&
                      !_allItems.any((i) =>
                          i.name.toLowerCase() ==
                          _itemSearchCtrl.text.trim().toLowerCase())
                  ? '+ Create "${_itemSearchCtrl.text.trim()}"'
                  : null,
              onCreate: _itemSearchCtrl.text.trim().isNotEmpty
                  ? () => _createAndAddItem(_itemSearchCtrl.text.trim())
                  : null,
              prefix: const Icon(Icons.add_rounded,
                  size: 16, color: AppColors.textMuted),
              onSubmit: () {
                final v = _itemSearchCtrl.text.trim();
                if (v.isEmpty) return;
                final match = _allItems.firstWhereOrNull(
                    (i) => i.name.toLowerCase() == v.toLowerCase());
                if (match != null) {
                  _addItem(match);
                } else {
                  _createAndAddItem(v);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Details section ────────────────────────────────────────────────────────

  Widget _buildDetailsSection() {
    final accountOptions =
        _accounts.map((a) => {'id': a.id, 'name': a.name}).toList();
    final selectedCat = _categoryId.isNotEmpty
        ? _categories.firstWhereOrNull((c) => c.id == _categoryId)
        : null;

    return FormCard(
      title: 'DETAILS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            label: 'DATE & TIME',
            value: fmtDateTime(widget.tx.date),
            editChild: _editing
                ? FieldBox(
                    onTap: _pickDateTime,
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(fmtDateTime(_date),
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                    ]),
                  )
                : null,
            editing: _editing,
          ),
          const SizedBox(height: 14),
          _DetailRow(
            label: 'STATUS',
            value: widget.tx.status,
            editChild: _editing
                ? StatusToggle(
                    selected: _status,
                    onChanged: (s) => setState(() => _status = s),
                  )
                : null,
            editing: _editing,
          ),
          if (widget.tx.type != 'transfer') ...[
            const SizedBox(height: 14),
            _DetailRow(
              label: 'ACCOUNT',
              value: widget.tx.accountName ?? '—',
              editChild: _editing
                  ? AccountDropdown(
                      accounts: accountOptions,
                      value: _accountId,
                      onChanged: (v) =>
                          setState(() => _accountId = v ?? _accountId),
                    )
                  : null,
              editing: _editing,
            ),
            const SizedBox(height: 14),
            _DetailRow(
              label: 'CATEGORY',
              value: widget.tx.categoryName != null
                  ? '${widget.tx.categoryIcon ?? ''} ${widget.tx.categoryName}'
                  : '—',
              editChild: _editing
                  ? FieldBox(
                      onTap: () => CategoryPicker.show(
                        context,
                        categories: _categories,
                        selectedId: _categoryId.isEmpty ? null : _categoryId,
                        onSelect: (id) =>
                            setState(() => _categoryId = id ?? ''),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            selectedCat != null
                                ? '${selectedCat.icon ?? ''} ${selectedCat.name}'
                                : 'Select category',
                            style: TextStyle(
                              color: selectedCat != null
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textMuted),
                      ]),
                    )
                  : null,
              editing: _editing,
            ),
            const SizedBox(height: 14),
            _DetailRow(
              label: 'MERCHANT',
              value: widget.tx.merchantName ?? '—',
              editChild: _editing
                  ? OverlayAutocomplete<Merchant>(
                      controller: _merchantCtrl,
                      hint: 'e.g. Swiggy...',
                      suggestions: _merchantSuggestions,
                      labelOf: (m) => m.name,
                      subtitleOf: (_) => null,
                      onChanged: (v) {
                        _merchantName = v;
                        setState(() {
                          _merchantSuggestions = v.isEmpty
                              ? []
                              : _merchants
                                  .where((m) => m.name
                                      .toLowerCase()
                                      .contains(v.toLowerCase()))
                                  .take(5)
                                  .toList();
                        });
                      },
                      onSelect: (m) => setState(() {
                        _merchantName = m.name;
                        _merchantCtrl.text = m.name;
                        _merchantSuggestions = [];
                      }),
                    )
                  : null,
              editing: _editing,
            ),
          ],
          const SizedBox(height: 14),
          _DetailRow(
            label: 'NOTE',
            value: widget.tx.note?.isNotEmpty == true ? widget.tx.note! : '—',
            editChild: _editing
                ? TextField(
                    controller: TextEditingController(text: _note),
                    onChanged: (v) => _note = v,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration:
                        const InputDecoration(hintText: 'Add a note...'),
                  )
                : null,
            editing: _editing,
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(double bottom) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: Color(0xCC0D0F17),
      ),
      child: _confirmDelete
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Delete this transaction? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FooterBtn(
                        label: 'Cancel',
                        onTap: () => setState(() => _confirmDelete = false),
                        subtle: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FooterBtn(
                        label: 'Yes, Delete',
                        onTap: _delete,
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
                      child: _FooterBtn(
                        label: 'Cancel',
                        onTap: () => setState(() => _editing = false),
                        subtle: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FooterBtn(
                        label: _saving ? 'Saving...' : 'Save',
                        onTap: _saving ? null : _save,
                        primary: true,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _FooterBtn(
                        label: 'Edit Transaction',
                        onTap: () => setState(() => _editing = true),
                        primary: true,
                        outline: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _FooterBtn(
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

// ── Item row (detail screen) ──────────────────────────────────────────────────

class _ItemRow extends StatefulWidget {
  final TxItem item;
  final bool editing;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ItemRow({
    required this.item,
    required this.editing,
    required this.onChanged,
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
    _amountCtrl =
        TextEditingController(text: widget.item.amount.toStringAsFixed(2));
    _qtyCtrl =
        TextEditingController(text: widget.item.quantity.toStringAsFixed(0));
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
                child: Text(widget.item.itemName,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Text(fmtCurrency(widget.item.subtotal),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              if (widget.editing) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(Icons.remove_circle_outline_rounded,
                      size: 17, color: AppColors.expense),
                ),
              ],
            ],
          ),
          if (widget.editing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child:
                        _mini(_amountCtrl, '₹', numeric: true, onChanged: (v) {
                  widget.item.amount = double.tryParse(v) ?? 0;
                  widget.onChanged();
                })),
                const SizedBox(width: 8),
                Expanded(
                    child: _mini(_qtyCtrl, '×', numeric: true, onChanged: (v) {
                  widget.item.quantity = double.tryParse(v) ?? 1;
                  widget.onChanged();
                })),
                const SizedBox(width: 8),
                Expanded(
                    child: _mini(_remarksCtrl, null, hint: 'Remark',
                        onChanged: (v) {
                  widget.item.remarks = v;
                  widget.onChanged();
                })),
              ],
            ),
          ] else if (widget.item.quantity > 1 ||
              widget.item.remarks.isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(children: [
              if (widget.item.quantity > 1) ...[
                Text('× ${widget.item.quantity.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(width: 6),
                Text('${fmtCurrency(widget.item.amount)} each',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
              if (widget.item.remarks.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(widget.item.remarks,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ]),
          ],
        ],
      ),
    );
  }

  Widget _mini(TextEditingController ctrl, String? prefix,
      {String? hint,
      bool numeric = false,
      required void Function(String) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (prefix != null) ...[
            Text(prefix,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
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

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? editChild;
  final bool editing;

  const _DetailRow({
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
        Text(label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            )),
        const SizedBox(height: 6),
        editing && editChild != null
            ? editChild!
            : Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Footer button ─────────────────────────────────────────────────────────────

class _FooterBtn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool subtle;
  final bool danger;
  final bool outline;
  final bool compact;

  const _FooterBtn({
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
    Color bg;
    Color fg;

    if (danger) {
      bg = AppColors.expense.withOpacity(0.1);
      fg = AppColors.expense;
    } else if (primary && !outline) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (primary && outline) {
      bg = AppColors.primary.withOpacity(0.1);
      fg = AppColors.primary;
    } else {
      bg = AppColors.surfaceHigh;
      fg = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: compact
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: primary && outline
              ? Border.all(color: AppColors.primary.withOpacity(0.3))
              : null,
        ),
        child: icon != null
            ? Icon(icon, color: fg, size: 18)
            : Center(
                child: Text(label ?? '',
                    style: TextStyle(
                        color: fg, fontSize: 14, fontWeight: FontWeight.w600))),
      ),
    );
  }
}

// ── Extension ─────────────────────────────────────────────────────────────────

extension _ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/animated_background.dart';
import '../transactions/transaction_models.dart';

// ---------------------------------------------------------------------------
// Local models
// ---------------------------------------------------------------------------

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

class _CartItem {
  final String itemId;
  final String name;
  double price;
  double quantity;
  String remarks;

  _CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.remarks = '',
  });

  double get subtotal => price * quantity;
}

class _CategoryOption {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  const _CategoryOption({
    required this.id,
    required this.name,
    this.icon,
    this.color,
  });
  factory _CategoryOption.fromJson(Map<String, dynamic> j) => _CategoryOption(
    id: j['id'] as String,
    name: j['name'] as String,
    icon: j['icon'] as String?,
    color: j['color'] as String?,
  );
}

class _AccountOption {
  final String id;
  final String name;
  final String type;
  final String? color;
  const _AccountOption({
    required this.id,
    required this.name,
    required this.type,
    this.color,
  });
  factory _AccountOption.fromJson(Map<String, dynamic> j) => _AccountOption(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String,
    color: j['color'] as String?,
  );
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

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  // Type
  String _type = 'expense';

  // Cart
  final List<_CartItem> _cart = [];

  // Form fields
  String _accountId = '';
  String _toAccountId = '';
  String _categoryId = '';
  String _merchantName = '';
  String _note = '';
  DateTime _date = DateTime.now();
  String _status = 'completed';

  // Data
  List<_AccountOption> _accounts = [];
  List<_CategoryOption> _categories = [];
  List<_MerchantOption> _merchants = [];
  List<_ItemSuggestion> _allItems = [];
  bool _loadingData = true;

  // Item search
  final _itemSearchCtrl = TextEditingController();
  final _itemFieldKey = GlobalKey();
  List<_ItemSuggestion> _itemSuggestions = [];
  OverlayEntry? _overlayEntry;

  // Merchant autocomplete
  final _merchantCtrl = TextEditingController();
  List<_MerchantOption> _merchantSuggestions = [];

  // Saving
  bool _saving = false;

  double get _total => _cart.fold(0, (sum, i) => sum + i.subtotal);

  @override
  void initState() {
    super.initState();
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
    // Snapshot suggestions so the overlay builder doesn't capture a mutable ref
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
                      _addToCart(s);
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
                      _createAndAdd(searchText);
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

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.fetchAccounts(),
        api.fetchCategories(),
        api.fetchMerchants(),
        api.fetchItems(),
      ]);
      setState(() {
        _accounts = (results[0] as List<dynamic>)
            .map((e) => _AccountOption.fromJson(e as Map<String, dynamic>))
            .toList();
        _categories = (results[1] as List<dynamic>)
            .map((e) => _CategoryOption.fromJson(e as Map<String, dynamic>))
            .toList();
        _merchants = (results[2] as List<dynamic>)
            .map((e) => _MerchantOption.fromJson(e as Map<String, dynamic>))
            .toList();
        _allItems = (results[3] as List<dynamic>)
            .map((e) => _ItemSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_accounts.isNotEmpty) {
          _accountId = _accounts.first.id;
          _toAccountId = _accounts.length > 1
              ? _accounts[1].id
              : _accounts.first.id;
        }
        _loadingData = false;
      });
    } catch (_) {
      setState(() => _loadingData = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Item search
  // ---------------------------------------------------------------------------

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

  void _addToCart(_ItemSuggestion s) {
    final existing = _cart.firstWhereOrNull((i) => i.itemId == s.id);
    if (existing != null) {
      setState(() => existing.quantity++);
    } else {
      setState(
        () => _cart.add(
          _CartItem(itemId: s.id, name: s.name, price: s.lastPrice),
        ),
      );
    }
    _itemSearchCtrl.clear();
    setState(() => _itemSuggestions = []);
    _removeOverlay();
    HapticFeedback.lightImpact();
  }

  Future<void> _createAndAdd(String name) async {
    try {
      final data = await ref.read(apiClientProvider).createItem(name);
      final s = _ItemSuggestion(
        id: data['id'] as String,
        name: data['name'] as String,
        lastPrice: 0,
      );
      _allItems.add(s);
      _addToCart(s);
    } catch (_) {}
  }

  void _removeFromCart(_CartItem item) {
    setState(() => _cart.remove(item));
    HapticFeedback.lightImpact();
  }

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
  // Category picker bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _showCategoryPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategoryBottomSheet(
        categories: _categories,
        selectedId: _categoryId,
        onSelect: (id) => setState(() => _categoryId = id),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (_cart.isEmpty) {
      _showSnackbar('Add at least one item first');
      return;
    }
    if (_accountId.isEmpty) {
      _showSnackbar('Select an account first');
      return;
    }
    if (_type == 'transfer' && _toAccountId == _accountId) {
      _showSnackbar('From and To accounts must be different');
      return;
    }

    setState(() => _saving = true);

    try {
      final api = ref.read(apiClientProvider);

      // Resolve merchant
      String? merchantId;
      final name = _merchantName.trim();
      if (name.isNotEmpty && _type != 'transfer') {
        final existing = _merchants.firstWhereOrNull(
          (m) => m.name.toLowerCase() == name.toLowerCase(),
        );
        if (existing != null) {
          merchantId = existing.id;
        } else {
          final created = await api.createMerchant(name);
          merchantId = created['id'] as String;
        }
      }

      // Build transaction payload
      final amount = _total > 0 ? _total : 0.01;
      final payload = <String, dynamic>{
        'type': _type,
        'amount': amount,
        'account_id': _accountId,
        'date': _date.toIso8601String(),
        'status': _status,
        if (_type == 'transfer') 'to_account_id': _toAccountId,
        if (_type != 'transfer' && _categoryId.isNotEmpty)
          'category_id': _categoryId,
        if (_type != 'transfer' && merchantId != null)
          'merchant_id': merchantId,
        if (_note.trim().isNotEmpty) 'note': _note.trim(),
      };

      final txResult = await api.dio.post('/api/transactions', data: payload);
      final txId = (txResult.data as Map<String, dynamic>)['id'] as String;

      // Add items
      await Future.wait(
        _cart.map(
          (item) => api.addTransactionItem(txId, {
            'item_id': item.itemId,
            'amount': item.price,
            'quantity': item.quantity,
            if (item.remarks.isNotEmpty) 'remarks': item.remarks,
          }),
        ),
      );

      if (mounted) {
        _showSnackbar('Transaction added ✓', success: true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop('added');
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to save: $e');
        setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(),
                _buildTypeTabs(),
                Expanded(
                  child: _loadingData
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            16,
                            20,
                            bottomPadding + 100,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTotalDisplay(),
                              const SizedBox(height: 24),
                              _buildItemsSection(),
                              const SizedBox(height: 24),
                              _buildFormSection(),
                            ],
                          ),
                        ),
                ),
                _buildSaveButton(bottomPadding),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
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
          const SizedBox(width: 14),
          const Text(
            'Add Transaction',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Type tabs
  // ---------------------------------------------------------------------------

  Widget _buildTypeTabs() {
    const types = [
      ('expense', '💸', 'Expense'),
      ('income', '💰', 'Income'),
      ('transfer', '🔄', 'Transfer'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: types.map((t) {
            final (value, emoji, label) = t;
            final selected = _type == value;
            final color = value == 'expense'
                ? AppColors.expense
                : value == 'income'
                ? AppColors.income
                : AppColors.primary;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _type = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: color.withOpacity(0.4))
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? color : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Total display
  // ---------------------------------------------------------------------------

  Widget _buildTotalDisplay() {
    final color = _type == 'expense'
        ? AppColors.expense
        : _type == 'income'
        ? AppColors.income
        : AppColors.primary;
    final prefix = _type == 'expense'
        ? '−'
        : _type == 'income'
        ? '+'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            _cart.isEmpty ? '₹0.00' : '$prefix${formatCurrency(_total)}',
            style: TextStyle(
              color: _cart.isEmpty ? AppColors.textMuted : color,
              fontSize: 42,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          if (_cart.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${_cart.length} item${_cart.length != 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Items section
  // ---------------------------------------------------------------------------

  Widget _buildItemsSection() {
    return _FormCard(
      title: 'ITEMS',
      child: Column(
        children: [
          // Cart items
          ..._cart.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CartItemRow(
                item: item,
                onChanged: () => setState(() {}),
                onRemove: () => _removeFromCart(item),
              ),
            ),
          ),

          if (_cart.isNotEmpty) ...[
            // Total row
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
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    formatCurrency(_total),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Item search — uses Overlay so suggestions float above scroll view
          Container(
            key: _itemFieldKey,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _itemSuggestions.isNotEmpty
                    ? AppColors.primary.withOpacity(0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.primary,
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
                      hintText: 'Search or create item...',
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
                        (i) => i.name.toLowerCase() == v.trim().toLowerCase(),
                      );
                      if (match != null) {
                        _addToCart(match);
                      } else {
                        await _createAndAdd(v.trim());
                      }
                      _removeOverlay();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form section
  // ---------------------------------------------------------------------------

  Widget _buildFormSection() {
    return _FormCard(
      title: 'DETAILS',
      child: Column(
        children: [
          // Account
          if (_type == 'transfer') ...[
            _FormRow(
              label: 'FROM',
              child: _AccountDropdown(
                accounts: _accounts,
                value: _accountId,
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
            const SizedBox(height: 14),
            _FormRow(
              label: 'TO',
              child: _AccountDropdown(
                accounts: _accounts,
                value: _toAccountId,
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
            ),
          ] else ...[
            _FormRow(
              label: 'ACCOUNT',
              child: _AccountDropdown(
                accounts: _accounts,
                value: _accountId,
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Date
          _FormRow(
            label: 'DATE',
            child: GestureDetector(
              onTap: () async {
                final pickedDate = await showDatePicker(
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
                if (pickedDate == null || !mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_date),
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
                final time = pickedTime ?? TimeOfDay.fromDateTime(_date);
                setState(
                  () => _date = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    time.hour,
                    time.minute,
                  ),
                );
              },
              child: _FieldBox(
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatDate(_date)}  ${formatTime(_date)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Status
          _FormRow(
            label: 'STATUS',
            child: Row(
              children: ['completed', 'pending'].map((s) {
                final selected = _status == s;
                final color = s == 'completed'
                    ? AppColors.income
                    : AppColors.pending;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withOpacity(0.12)
                            : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? color.withOpacity(0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(
                          color: selected ? color : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Category + Merchant (not for transfer)
          if (_type != 'transfer') ...[
            const SizedBox(height: 14),
            _FormRow(
              label: 'CATEGORY',
              child: GestureDetector(
                onTap: _showCategoryPicker,
                child: _FieldBox(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryId.isEmpty
                              ? 'Select category'
                              : () {
                                  final cat = _categories.firstWhereOrNull(
                                    (c) => c.id == _categoryId,
                                  );
                                  return cat != null
                                      ? '${cat.icon ?? ''} ${cat.name}'
                                      : 'Select category';
                                }(),
                          style: TextStyle(
                            color: _categoryId.isEmpty
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _FormRow(
              label: 'MERCHANT',
              child: Column(
                children: [
                  TextField(
                    controller: _merchantCtrl,
                    onChanged: _onMerchantChanged,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Swiggy, Amazon...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
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
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          // Note
          _FormRow(
            label: 'NOTE',
            child: TextField(
              onChanged: (v) => _note = v,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Optional note...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
  // Save button
  // ---------------------------------------------------------------------------

  Widget _buildSaveButton(double bottomPadding) {
    final canSave = _cart.isNotEmpty && !_saving;
    final color = _type == 'expense'
        ? AppColors.expense
        : _type == 'income'
        ? AppColors.income
        : AppColors.primary;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: Color(0xCC0F1117),
      ),
      child: GestureDetector(
        onTap: canSave ? _save : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 54,
          decoration: BoxDecoration(
            gradient: canSave
                ? LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: canSave ? null : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            boxShadow: canSave
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _cart.isEmpty
                        ? 'Add items to continue'
                        : 'Save ${_type[0].toUpperCase()}${_type.substring(1)}',
                    style: TextStyle(
                      color: canSave ? Colors.white : AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category bottom sheet
// ---------------------------------------------------------------------------

class _CategoryBottomSheet extends StatefulWidget {
  final List<_CategoryOption> categories;
  final String selectedId;
  final void Function(String) onSelect;

  const _CategoryBottomSheet({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<_CategoryBottomSheet> createState() => _CategoryBottomSheetState();
}

class _CategoryBottomSheetState extends State<_CategoryBottomSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.categories
        : widget.categories
              .where(
                (c) => c.name.toLowerCase().contains(_search.toLowerCase()),
              )
              .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Category',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          // Search
          Container(
            height: 42,
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
                  size: 16,
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
                      hintText: 'Search...',
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          // None option
          _CategoryTile(
            icon: '—',
            name: 'None',
            color: null,
            selected: widget.selectedId.isEmpty,
            onTap: () {
              widget.onSelect('');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 4),
          // Categories
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final c = filtered[i];
                return _CategoryTile(
                  icon: c.icon ?? '📁',
                  name: c.name,
                  color: c.color,
                  selected: widget.selectedId == c.id,
                  onTap: () {
                    widget.onSelect(c.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String icon;
  final String name;
  final String? color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  Color get _parsedColor {
    if (color == null) return AppColors.primary;
    final c = color!.replaceFirst('#', '');
    if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final c = _parsedColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.1) : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: selected ? c : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: c, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cart item row
// ---------------------------------------------------------------------------

class _CartItemRow extends StatefulWidget {
  final _CartItem item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<_CartItemRow> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _remarksCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.item.price > 0 ? widget.item.price.toStringAsFixed(2) : '',
    );
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
    _remarksCtrl = TextEditingController(text: widget.item.remarks);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
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
                  widget.item.name,
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 18,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniField(
                  controller: _priceCtrl,
                  prefix: '₹',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) {
                    widget.item.price = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniField(
                  controller: _qtyCtrl,
                  prefix: '×',
                  hint: '1',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) {
                    widget.item.quantity = double.tryParse(v) ?? 1;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniField(
                  controller: _remarksCtrl,
                  hint: 'Remark',
                  onChanged: (v) {
                    widget.item.remarks = v;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _FormCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _FormCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormRow({required this.label, required this.child});

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
        child,
      ],
    );
  }
}

class _FieldBox extends StatelessWidget {
  final Widget child;
  const _FieldBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  final List<_AccountOption> accounts;
  final String value;
  final void Function(String) onChanged;

  const _AccountDropdown({
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: const Text(
            'Select account',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          dropdownColor: AppColors.surfaceHigh,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          isExpanded: true,
          isDense: true,
          items: accounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
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
          if (prefix != null) ...[
            Text(
              prefix!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(width: 4),
          ],
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

extension _ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

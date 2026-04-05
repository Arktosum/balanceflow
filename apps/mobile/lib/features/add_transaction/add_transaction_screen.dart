import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/models.dart';
import '../../shared/widgets/animated_background.dart';
import '../../shared/widgets/overlay_autocomplete.dart';
import 'widgets/type_selector.dart';
import 'widgets/cart_item_row.dart';
import 'widgets/category_picker.dart';
import 'widgets/form_widgets.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  String _type = 'expense';
  final List<CartItem> _cart = [];
  final _amountCtrl = TextEditingController();
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String _merchantName = '';
  String _note = '';
  DateTime _date = DateTime.now();
  String _status = 'completed';
  bool _saving = false;

  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Merchant> _merchants = [];
  List<ItemSuggestion> _allItems = [];
  bool _loading = true;

  final _itemSearchCtrl = TextEditingController();
  List<ItemSuggestion> _itemSuggestions = [];

  final _merchantCtrl = TextEditingController();
  List<Merchant> _merchantSuggestions = [];

  double get _cartTotal => _cart.fold(0, (sum, i) => sum + i.subtotal);

  double get _transferAmount => double.tryParse(_amountCtrl.text) ?? 0;

  bool get _canSave {
    if (_accountId == null) return false;
    if (_type == 'transfer') {
      return _toAccountId != null &&
          _toAccountId != _accountId &&
          _transferAmount > 0;
    }
    return _cart.isNotEmpty;
  }

  Color get _typeColor => switch (_type) {
        'income' => AppColors.income,
        'transfer' => AppColors.primary,
        _ => AppColors.expense,
      };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _itemSearchCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
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
        _accounts = (results[0] as List)
            .map((e) => Account.fromJson(e as Map<String, dynamic>))
            .toList();
        _categories = (results[1] as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
        _merchants = (results[2] as List)
            .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
            .toList();
        _allItems = (results[3] as List)
            .map((e) => ItemSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_accounts.isNotEmpty) {
          _accountId = _accounts.first.id;
          _toAccountId = _accounts.length > 1 ? _accounts[1].id : null;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
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
  }

  void _addToCart(ItemSuggestion s) {
    final existing = _cart.firstWhereOrNull((i) => i.itemId == s.id);
    if (existing != null) {
      setState(() => existing.quantity++);
    } else {
      setState(() => _cart.add(CartItem(
            itemId: s.id,
            name: s.name,
            price: s.lastPrice,
          )));
    }
    _itemSearchCtrl.clear();
    setState(() => _itemSuggestions = []);
    HapticFeedback.lightImpact();
  }

  Future<void> _createAndAdd(String name) async {
    try {
      final data = await ref.read(apiClientProvider).createItem(name);
      final s = ItemSuggestion.fromJson(data);
      _allItems.add(s);
      _addToCart(s);
    } catch (_) {}
  }

  void _onMerchantSearch(String v) {
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

  Future<void> _save() async {
    if (!_canSave) return;
    // Guard: all items must have a price
    if (_type != 'transfer') {
      final zeroPriceItem = _cart.firstWhereOrNull((i) => i.price <= 0);
      if (zeroPriceItem != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Set a price for "\${zeroPriceItem.name}"'),
          backgroundColor: AppColors.expense,
        ));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      String? merchantId;
      final mName = _merchantName.trim();
      if (mName.isNotEmpty && _type != 'transfer') {
        final existing = _merchants.firstWhereOrNull(
            (m) => m.name.toLowerCase() == mName.toLowerCase());
        if (existing != null) {
          merchantId = existing.id;
        } else {
          final created = await api.createMerchant(mName);
          merchantId = created['id'] as String;
        }
      }
      final amount = _type == 'transfer' ? _transferAmount : _cartTotal;
      final payload = <String, dynamic>{
        'type': _type,
        'amount': amount,
        'account_id': _accountId,
        'date': _date.toUtc().toIso8601String(),
        'status': _status,
        if (_type == 'transfer') 'to_account_id': _toAccountId,
        if (_type != 'transfer' && _categoryId != null)
          'category_id': _categoryId,
        if (_type != 'transfer' && merchantId != null)
          'merchant_id': merchantId,
        if (_note.trim().isNotEmpty) 'note': _note.trim(),
      };
      final tx = await api.createTransaction(payload);
      final txId = tx['id'] as String;
      if (_cart.isNotEmpty) {
        await Future.wait(_cart.map((item) => api.addTransactionItem(txId, {
              'item_id': item.itemId,
              'amount': item.price,
              'quantity': item.quantity,
              if (item.remarks.isNotEmpty) 'remarks': item.remarks,
            })));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${_type[0].toUpperCase()}${_type.substring(1)} saved ✓'),
          backgroundColor: _typeColor,
        ));
        Navigator.of(context).pop('added');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.expense,
        ));
        setState(() => _saving = false);
      }
    }
  }

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
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : SingleChildScrollView(
                          padding:
                              EdgeInsets.fromLTRB(20, 16, 20, bottom + 110),
                          child: Column(
                            children: [
                              TypeSelector(
                                selected: _type,
                                onChanged: (t) => setState(() => _type = t),
                              ),
                              const SizedBox(height: 16),
                              _buildTotalHero(),
                              const SizedBox(height: 16),
                              _buildItemsCard(),
                              if (_type != 'transfer')
                                const SizedBox(height: 16),
                              _buildDetailsCard(),
                            ],
                          ),
                        ),
                ),
                _buildSaveBar(bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() => Padding(
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
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 14),
            const Text('Add Transaction',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                )),
          ],
        ),
      );

  Widget _buildTotalHero() {
    final prefix = _type == 'expense'
        ? '−'
        : _type == 'income'
            ? '+'
            : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_typeColor.withOpacity(0.12), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _typeColor.withOpacity(0.2)),
      ),
      child: _type == 'transfer'
          ? _TransferAmountField(
              controller: _amountCtrl,
              color: _typeColor,
              onChanged: () => setState(() {}),
            )
          : Column(
              children: [
                Text(
                  _cart.isEmpty ? '₹0.00' : '$prefix${fmtCurrency(_cartTotal)}',
                  style: TextStyle(
                    color: _cart.isEmpty ? AppColors.textMuted : _typeColor,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                if (_cart.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_cart.length} item${_cart.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildItemsCard() {
    if (_type == 'transfer') return const SizedBox.shrink();
    return FormCard(
      title: 'ITEMS',
      child: Column(
        children: [
          ..._cart.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CartItemRow(
                  key: ValueKey(item.itemId),
                  item: item,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _cart.remove(item)),
                ),
              )),
          if (_cart.isNotEmpty) ...[
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
                  Text(fmtCurrency(_cartTotal),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          OverlayAutocomplete<ItemSuggestion>(
            controller: _itemSearchCtrl,
            hint: 'Search or create item...',
            suggestions: _itemSuggestions,
            labelOf: (s) => s.name,
            subtitleOf: (s) =>
                s.lastPrice > 0 ? fmtCurrency(s.lastPrice) : null,
            onChanged: _onItemSearch,
            onSelect: _addToCart,
            createLabel: _itemSearchCtrl.text.trim().isNotEmpty &&
                    !_allItems.any((i) =>
                        i.name.toLowerCase() ==
                        _itemSearchCtrl.text.trim().toLowerCase())
                ? '+ Create "${_itemSearchCtrl.text.trim()}"'
                : null,
            onCreate: _itemSearchCtrl.text.trim().isNotEmpty
                ? () => _createAndAdd(_itemSearchCtrl.text.trim())
                : null,
            prefix: const Icon(Icons.add_rounded,
                size: 18, color: AppColors.primary),
            onSubmit: () {
              final v = _itemSearchCtrl.text.trim();
              if (v.isEmpty) return;
              final match = _allItems.firstWhereOrNull(
                  (i) => i.name.toLowerCase() == v.toLowerCase());
              if (match != null) {
                _addToCart(match);
              } else {
                _createAndAdd(v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final accountOptions =
        _accounts.map((a) => {'id': a.id, 'name': a.name}).toList();
    final selectedCategory = _categoryId != null
        ? _categories.firstWhereOrNull((c) => c.id == _categoryId)
        : null;

    return FormCard(
      title: 'DETAILS',
      child: Column(
        children: [
          FormRow(
            label: _type == 'transfer' ? 'FROM ACCOUNT' : 'ACCOUNT',
            child: AccountDropdown(
              accounts: accountOptions,
              value: _accountId,
              onChanged: (v) => setState(() => _accountId = v),
            ),
          ),
          if (_type == 'transfer') ...[
            const SizedBox(height: 14),
            FormRow(
              label: 'TO ACCOUNT',
              child: AccountDropdown(
                accounts:
                    accountOptions.where((a) => a['id'] != _accountId).toList(),
                value: _toAccountId == _accountId ? null : _toAccountId,
                hint: 'Select destination',
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FormRow(
            label: 'DATE & TIME',
            child: FieldBox(
              onTap: _pickDateTime,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(fmtDateTime(_date),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FormRow(
            label: 'STATUS',
            child: StatusToggle(
              selected: _status,
              onChanged: (s) => setState(() => _status = s),
            ),
          ),
          if (_type != 'transfer') ...[
            const SizedBox(height: 14),
            FormRow(
              label: 'CATEGORY',
              child: FieldBox(
                onTap: () => CategoryPicker.show(
                  context,
                  categories: _categories,
                  selectedId: _categoryId,
                  onSelect: (id) => setState(() => _categoryId = id),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedCategory != null
                            ? '${selectedCategory.icon ?? ''} ${selectedCategory.name}'
                            : 'Select category',
                        style: TextStyle(
                          color: selectedCategory != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FormRow(
              label: 'MERCHANT',
              child: OverlayAutocomplete<Merchant>(
                controller: _merchantCtrl,
                hint: 'e.g. Swiggy, Amazon...',
                suggestions: _merchantSuggestions,
                labelOf: (m) => m.name,
                subtitleOf: (_) => null,
                onChanged: _onMerchantSearch,
                onSelect: (m) => setState(() {
                  _merchantName = m.name;
                  _merchantCtrl.text = m.name;
                  _merchantSuggestions = [];
                }),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FormRow(
            label: 'NOTE',
            child: TextField(
              onChanged: (v) => _note = v,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(hintText: 'Optional note...'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(double bottomPadding) {
    String label;
    if (!_canSave) {
      label = _type == 'transfer'
          ? 'Enter amount & select accounts'
          : 'Add items to continue';
    } else {
      label = 'Save ${_type[0].toUpperCase()}${_type.substring(1)}';
    }
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: Color(0xCC0D0F17),
      ),
      child: GestureDetector(
        onTap: (_canSave && !_saving) ? _save : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 54,
          decoration: BoxDecoration(
            gradient: (_canSave && !_saving)
                ? LinearGradient(
                    colors: [_typeColor, _typeColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: (_canSave && !_saving) ? null : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            boxShadow: (_canSave && !_saving)
                ? [
                    BoxShadow(
                      color: _typeColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: _canSave ? Colors.white : AppColors.textMuted,
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

class _TransferAmountField extends StatelessWidget {
  final TextEditingController controller;
  final Color color;
  final VoidCallback onChanged;

  const _TransferAmountField({
    required this.controller,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('₹',
            style: TextStyle(
                color: color, fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: color,
              fontSize: 42,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                  color: color.withOpacity(0.3),
                  fontSize: 42,
                  fontWeight: FontWeight.w700),
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

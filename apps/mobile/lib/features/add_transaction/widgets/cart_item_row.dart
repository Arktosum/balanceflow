import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class CartItem {
  final String itemId;
  final String name;
  double price;
  double quantity;
  String remarks;

  CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.remarks = '',
  });

  double get subtotal => price * quantity;
}

// ── Row widget ────────────────────────────────────────────────────────────────

class CartItemRow extends StatefulWidget {
  final CartItem item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const CartItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<CartItemRow> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _remarksCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.item.price > 0
          ? widget.item.price.toStringAsFixed(2)
          : '',
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Name row + subtotal + remove
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
                fmtCurrency(widget.item.subtotal),
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
          // Inline fields
          Row(
            children: [
              Expanded(
                child: _MiniField(
                  controller: _priceCtrl,
                  prefix: '₹',
                  hint: '0.00',
                  numeric: true,
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
                  numeric: true,
                  onChanged: (v) {
                    widget.item.quantity =
                        double.tryParse(v) ?? 1;
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

// ── Mini text field ───────────────────────────────────────────────────────────

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String? prefix;
  final String hint;
  final bool numeric;
  final void Function(String) onChanged;

  const _MiniField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.prefix,
    this.numeric = false,
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
            Text(prefix!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              inputFormatters: numeric
                  ? [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'))
                    ]
                  : null,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
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
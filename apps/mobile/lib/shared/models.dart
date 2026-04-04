import 'package:flutter/material.dart';

// ── Formatters ────────────────────────────────────────────────────────────────

double toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

String fmtCurrency(double v) {
  final neg = v < 0;
  final abs = v.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final dec = parts[1];
  String grouped;
  if (intPart.length <= 3) {
    grouped = intPart;
  } else {
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    grouped = '${buf.toString()},$last3';
  }
  return '${neg ? '-' : ''}₹$grouped.$dec';
}

String fmtDate(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final date = DateTime(d.year, d.month, d.day);
  if (date == today) return 'Today';
  if (date == yesterday) return 'Yesterday';
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final min = d.minute.toString().padLeft(2, '0');
  return '$h:$min ${d.hour < 12 ? 'AM' : 'PM'}';
}

String fmtDateTime(DateTime d) => '${fmtDate(d)}  ${fmtTime(d)}';

Color parseHexColor(String? hex, {Color fallback = const Color(0xFF6C63FF)}) {
  if (hex == null) return fallback;
  final c = hex.replaceFirst('#', '');
  if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
  return fallback;
}

// ── Models ────────────────────────────────────────────────────────────────────

class Account {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String? color;
  final String? icon;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.color,
    this.icon,
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String? ?? 'cash',
        balance: toDouble(j['balance']),
        color: j['color'] as String?,
        icon: j['icon'] as String?,
      );

  Color get parsedColor => parseHexColor(color);

  IconData get typeIcon => switch (type) {
        'bank' => Icons.account_balance_rounded,
        'wallet' => Icons.account_balance_wallet_rounded,
        'credit' => Icons.credit_card_rounded,
        _ => Icons.payments_rounded,
      };
}

class Category {
  final String id;
  final String name;
  final String? icon;
  final String? color;

  const Category({required this.id, required this.name, this.icon, this.color});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String?,
        color: j['color'] as String?,
      );

  Color get parsedColor => parseHexColor(color);
}

class Merchant {
  final String id;
  final String name;

  const Merchant({required this.id, required this.name});

  factory Merchant.fromJson(Map<String, dynamic> j) =>
      Merchant(id: j['id'] as String, name: j['name'] as String);
}

class ItemSuggestion {
  final String id;
  final String name;
  final double lastPrice;

  const ItemSuggestion(
      {required this.id, required this.name, required this.lastPrice});

  factory ItemSuggestion.fromJson(Map<String, dynamic> j) => ItemSuggestion(
        id: j['id'] as String,
        name: j['name'] as String,
        lastPrice: toDouble(j['last_price']),
      );
}

class Transaction {
  final String id;
  final String type;
  final double amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? merchantId;
  final String? note;
  final DateTime date;
  final String status;
  final String? accountName;
  final String? toAccountName;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? merchantName;
  final int itemCount;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.merchantId,
    this.note,
    required this.date,
    required this.status,
    this.accountName,
    this.toAccountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.merchantName,
    this.itemCount = 0,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        type: j['type'] as String,
        amount: toDouble(j['amount']),
        accountId: j['account_id'] as String,
        toAccountId: j['to_account_id'] as String?,
        categoryId: j['category_id'] as String?,
        merchantId: j['merchant_id'] as String?,
        note: j['note'] as String?,
        date: DateTime.parse(j['date'] as String).toLocal(),
        status: j['status'] as String? ?? 'completed',
        accountName: j['account_name'] as String?,
        toAccountName: j['to_account_name'] as String?,
        categoryName: j['category_name'] as String?,
        categoryIcon: j['category_icon'] as String?,
        categoryColor: j['category_color'] as String?,
        merchantName: j['merchant_name'] as String?,
        itemCount: (j['item_count'] as int?) ?? 0,
      );

  Color get amountColor => switch (type) {
        'income' => const Color(0xFF22C55E),
        'transfer' => const Color(0xFF6C63FF),
        _ => const Color(0xFFEF4444),
      };

  String get amountPrefix => switch (type) {
        'income' => '+',
        'expense' => '−',
        _ => '',
      };

  String get defaultEmoji => switch (type) {
        'income' => '💰',
        'transfer' => '🔄',
        _ => '💸',
      };
}

class TxItem {
  final String id;
  final String itemId;
  final String itemName;
  double amount;
  double quantity;
  String remarks;

  TxItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.amount,
    required this.quantity,
    this.remarks = '',
  });

  factory TxItem.fromJson(Map<String, dynamic> j) => TxItem(
        id: j['id'] as String? ?? '',
        itemId: j['item_id'] as String,
        itemName: j['item_name'] as String,
        amount: toDouble(j['amount']),
        quantity: toDouble(j['quantity']),
        remarks: j['remarks'] as String? ?? '',
      );

  double get subtotal => amount * quantity;
}

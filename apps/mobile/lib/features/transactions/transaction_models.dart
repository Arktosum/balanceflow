class TxModel {
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

  const TxModel({
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

  factory TxModel.fromJson(Map<String, dynamic> j) => TxModel(
    id: j['id'] as String,
    type: j['type'] as String,
    amount: toDouble(j['amount']),
    accountId: j['account_id'] as String,
    toAccountId: j['to_account_id'] as String?,
    categoryId: j['category_id'] as String?,
    merchantId: j['merchant_id'] as String?,
    note: j['note'] as String?,
    date: DateTime.parse(j['date'] as String),
    status: j['status'] as String? ?? 'completed',
    accountName: j['account_name'] as String?,
    toAccountName: j['to_account_name'] as String?,
    categoryName: j['category_name'] as String?,
    categoryIcon: j['category_icon'] as String?,
    categoryColor: j['category_color'] as String?,
    merchantName: j['merchant_name'] as String?,
    itemCount: (j['item_count'] as int?) ?? 0,
  );
}

class AccountModel {
  final String id;
  final String name;
  const AccountModel({required this.id, required this.name});
  factory AccountModel.fromJson(Map<String, dynamic> j) =>
      AccountModel(id: j['id'] as String, name: j['name'] as String);
}

class MerchantModel {
  final String id;
  final String name;
  const MerchantModel({required this.id, required this.name});
  factory MerchantModel.fromJson(Map<String, dynamic> j) =>
      MerchantModel(id: j['id'] as String, name: j['name'] as String);
}

double toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

String formatCurrency(double v) {
  final isNegative = v < 0;
  final abs = v.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
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

String formatDate(DateTime d) {
  const months = [
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
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final date = DateTime(d.year, d.month, d.day);
  if (date == today) return 'Today';
  if (date == yesterday) return 'Yesterday';
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

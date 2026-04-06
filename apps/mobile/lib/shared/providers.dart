import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The account ID to pre-filter on the Transactions tab.
/// Set by Accounts screen when user taps an account.
/// Read and cleared by TransactionsScreen on first build.
final txAccountFilterProvider = StateProvider<String?>((ref) => null);
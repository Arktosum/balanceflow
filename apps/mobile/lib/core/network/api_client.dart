import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) options.headers['x-app-token'] = token;
        handler.next(options);
      },
      onError: (error, handler) {
        // ignore: avoid_print
        print(
            '[API ERROR] ${error.requestOptions.method} ${error.requestOptions.path}');
        // ignore: avoid_print
        print('[API ERROR] body: ${error.requestOptions.data}');
        // ignore: avoid_print
        print('[API ERROR] status: ${error.response?.statusCode}');
        // ignore: avoid_print
        print('[API ERROR] response: ${error.response?.data}');
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<String?> validateToken(String token) async {
    try {
      final res = await _dio.get(
        '/api/accounts',
        options: Options(headers: {'x-app-token': token}),
      );
      if (res.statusCode == 200) return null;
      return 'Server error ${res.statusCode}';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server';
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Wrong password';
      }
      return 'Error: ${e.message}';
    }
  }

  Future<void> saveToken(String t) =>
      _storage.write(key: AppConstants.tokenKey, value: t);
  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);
  Future<void> clearToken() => _storage.delete(key: AppConstants.tokenKey);

  // ── Accounts ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchAccounts() async =>
      (await _dio.get('/api/accounts')).data as List<dynamic>;

  // ── Categories ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchCategories() async =>
      (await _dio.get('/api/categories')).data as List<dynamic>;

  // ── Merchants ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchMerchants() async =>
      (await _dio.get('/api/merchants')).data as List<dynamic>;

  Future<Map<String, dynamic>> createMerchant(String name) async =>
      (await _dio.post('/api/merchants', data: {'name': name})).data
          as Map<String, dynamic>;

  // ── Items ──────────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchItems() async =>
      (await _dio.get('/api/items')).data as List<dynamic>;

  Future<Map<String, dynamic>> createItem(String name) async =>
      (await _dio.post('/api/items', data: {'name': name})).data
          as Map<String, dynamic>;

  // ── Transactions ───────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchTransactions({
    String? type,
    String? status,
    String? accountId,
    String? merchantId,
    String? from,
    String? to,
    int limit = 200,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;
    if (accountId != null) params['account_id'] = accountId;
    if (merchantId != null) params['merchant_id'] = merchantId;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return (await _dio.get('/api/transactions', queryParameters: params)).data
        as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction(
          Map<String, dynamic> data) async =>
      (await _dio.post('/api/transactions', data: data)).data
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateTransaction(
          String id, Map<String, dynamic> data) async =>
      (await _dio.patch('/api/transactions/$id', data: data)).data
          as Map<String, dynamic>;

  Future<void> deleteTransaction(String id) =>
      _dio.delete('/api/transactions/$id');

  // ── Transaction items ──────────────────────────────────────────────────────

  Future<List<dynamic>> fetchTransactionItems(String txId) async =>
      (await _dio.get('/api/transactions/$txId/items')).data as List<dynamic>;

  Future<void> addTransactionItem(String txId, Map<String, dynamic> data) =>
      _dio.post('/api/transactions/$txId/items', data: data);

  Future<void> updateTransactionItem(
          String itemId, Map<String, dynamic> data) =>
      _dio.patch('/api/transaction-items/$itemId', data: data);

  Future<void> deleteTransactionItem(String itemId) =>
      _dio.delete('/api/transaction-items/$itemId');

  // ── Analytics ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchAnalyticsSummary({
    required String period,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return (await _dio.get('/api/analytics/summary', queryParameters: params))
        .data as Map<String, dynamic>;
  }

  // These three return dynamic — backend may return { key: [...] } or [...] directly
  Future<dynamic> fetchAnalyticsByCategory({
    required String period,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return (await _dio.get('/api/analytics/by-category',
            queryParameters: params))
        .data;
  }

  Future<dynamic> fetchAnalyticsByMerchant({
    required String period,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return (await _dio.get('/api/analytics/by-merchant',
            queryParameters: params))
        .data;
  }

  Future<dynamic> fetchAnalyticsByItem({
    required String period,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return (await _dio.get('/api/analytics/by-item', queryParameters: params))
        .data;
  }
}

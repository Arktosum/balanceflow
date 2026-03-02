import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.tokenKey);
          if (token != null) options.headers['x-app-token'] = token;
          return handler.next(options);
        },
      ),
    );
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> validateToken(String token) async {
    try {
      final res = await _dio.get(
        '/api/accounts',
        options: Options(headers: {'x-app-token': token}),
      );
      if (res.statusCode == 200) return null;
      return 'Server returned status ${res.statusCode}';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out — is the server running?';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server — check your URL in constants.dart';
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Wrong password';
      }
      if (e.response != null) {
        return 'Server error ${e.response?.statusCode}: ${e.response?.statusMessage}';
      }
      return 'Network error: ${e.message}';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.tokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);
  Future<void> clearToken() => _storage.delete(key: AppConstants.tokenKey);

  // ── Accounts ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchAccounts() async =>
      (await _dio.get('/api/accounts')).data as List<dynamic>;

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchCategories() async =>
      (await _dio.get('/api/categories')).data as List<dynamic>;

  // ── Merchants ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchMerchants() async =>
      (await _dio.get('/api/merchants')).data as List<dynamic>;

  Future<Map<String, dynamic>> createMerchant(String name) async =>
      (await _dio.post('/api/merchants', data: {'name': name})).data
          as Map<String, dynamic>;

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchTransactions({
    String? type,
    String? status,
    String? accountId,
    String? merchantId,
    int limit = 100,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;
    if (accountId != null) params['account_id'] = accountId;
    if (merchantId != null) params['merchant_id'] = merchantId;
    return (await _dio.get('/api/transactions', queryParameters: params)).data
        as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async =>
      (await _dio.patch('/api/transactions/$id', data: data)).data
          as Map<String, dynamic>;

  Future<void> deleteTransaction(String id) =>
      _dio.delete('/api/transactions/$id');

  // ── Transaction items ─────────────────────────────────────────────────────

  Future<List<dynamic>> fetchTransactionItems(String txId) async =>
      (await _dio.get('/api/transactions/$txId/items')).data as List<dynamic>;

  Future<void> addTransactionItem(String txId, Map<String, dynamic> data) =>
      _dio.post('/api/transactions/$txId/items', data: data);

  Future<void> updateTransactionItem(
    String itemId,
    Map<String, dynamic> data,
  ) => _dio.patch('/api/transactions/items/$itemId', data: data);

  Future<void> deleteTransactionItem(String itemId) =>
      _dio.delete('/api/transactions/items/$itemId');

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchItems() async =>
      (await _dio.get('/api/items')).data as List<dynamic>;

  Future<Map<String, dynamic>> createItem(String name) async =>
      (await _dio.post('/api/items', data: {'name': name})).data
          as Map<String, dynamic>;

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchAnalyticsSummary({
    required String period,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{'period': period};
    if (period == 'custom' && from != null && to != null) {
      params['from'] = from.toIso8601String();
      params['to'] = to.toIso8601String();
    }
    return (await _dio.get(
          '/api/analytics/summary',
          queryParameters: params,
        )).data
        as Map<String, dynamic>;
  }

  Dio get dio => _dio;
}

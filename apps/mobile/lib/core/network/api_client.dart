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

  /// Returns null on success, or an error message string on failure.
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

  Future<List<dynamic>> fetchAccounts() async {
    final res = await _dio.get('/api/accounts');
    return res.data as List<dynamic>;
  }

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
    final res = await _dio.get(
      '/api/analytics/summary',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>;
  }

  Dio get dio => _dio;
}

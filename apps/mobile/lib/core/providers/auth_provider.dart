import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({bool? isLoading, bool? isAuthenticated, String? error}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        error: error,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _init() async {
    final token = await _api.getToken();
    if (token == null) {
      state = const AuthState(isLoading: false);
      return;
    }
    final valid = await _api.validateToken(token);
    state = AuthState(isLoading: false, isAuthenticated: valid);
  }

  Future<void> login(String token) async {
    state = state.copyWith(isLoading: true, error: null);
    final valid = await _api.validateToken(token.trim());
    if (!valid) {
      state = const AuthState(
        isLoading: false,
        error: 'Invalid password — check your APP_SECRET',
      );
      return;
    }
    await _api.saveToken(token.trim());
    state = const AuthState(isLoading: false, isAuthenticated: true);
  }

  Future<void> logout() async {
    await _api.clearToken();
    state = const AuthState(isLoading: false);
  }
}

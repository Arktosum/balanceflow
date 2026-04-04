import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.error,
  });

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? error}) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
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
      state = const AuthState(isAuthenticated: false, isLoading: false);
      return;
    }
    final error = await _api.validateToken(token);
    state = AuthState(isAuthenticated: error == null, isLoading: false);
  }

  Future<void> login(String token) async {
    state = state.copyWith(isLoading: true, error: null);
    final error = await _api.validateToken(token.trim());
    if (error != null) {
      state = AuthState(isAuthenticated: false, isLoading: false, error: error);
      return;
    }
    await _api.saveToken(token.trim());
    state = const AuthState(isAuthenticated: true, isLoading: false);
  }

  Future<void> logout() async {
    await _api.clearToken();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/providers/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../shared/widgets/app_shell.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'BalanceFlow',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: auth.isLoading
          ? const _Splash()
          : auth.isAuthenticated
              ? const AppShell()
              : const LoginScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }
}

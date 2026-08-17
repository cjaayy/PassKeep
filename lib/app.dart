import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/auth_lock_screen.dart';
import 'features/auth/presentation/screens/setup_master_pin_screen.dart';
import 'features/vault/presentation/screens/vault_home_screen.dart';

/// Root widget for PassKeep application with reactive authentication routing
class PassKeepApp extends ConsumerWidget {
  const PassKeepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return MaterialApp(
      title: 'PassKeep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: _buildHome(authState.status),
    );
  }

  Widget _buildHome(AuthStatus status) {
    switch (status) {
      case AuthStatus.uninitialized:
        return const SetupMasterPinScreen();
      case AuthStatus.locked:
        return const AuthLockScreen();
      case AuthStatus.authenticated:
        return const VaultHomeScreen();
      case AuthStatus.loading:
        return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          ),
        );
    }
  }
}

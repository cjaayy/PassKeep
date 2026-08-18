import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/observers/app_lock_observer.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/auth_lock_screen.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'features/vault/presentation/screens/vault_home_screen.dart';

/// Root widget for PassKeep application with reactive authentication routing and auto-lock lifecycle monitoring
class PassKeepApp extends ConsumerStatefulWidget {
  const PassKeepApp({super.key});

  @override
  ConsumerState<PassKeepApp> createState() => _PassKeepAppState();
}

class _PassKeepAppState extends ConsumerState<PassKeepApp> {
  late AppLockObserver _lockObserver;

  @override
  void initState() {
    super.initState();
    _lockObserver = AppLockObserver(ref: ref);
    _lockObserver.register();
  }

  @override
  void dispose() {
    _lockObserver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final settingsState = ref.watch(settingsNotifierProvider);

    return MaterialApp(
      title: 'PassKeep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsState.themeMode,
      home: _buildHome(context, authState.status),
    );
  }

  Widget _buildHome(BuildContext context, AuthStatus status) {
    switch (status) {
      case AuthStatus.uninitialized:
        return const WelcomeScreen();
      case AuthStatus.locked:
        return const AuthLockScreen();
      case AuthStatus.authenticated:
        return const VaultHomeScreen();
      case AuthStatus.loading:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          body: Center(
            child: CircularProgressIndicator(
              color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
            ),
          ),
        );
    }
  }
}

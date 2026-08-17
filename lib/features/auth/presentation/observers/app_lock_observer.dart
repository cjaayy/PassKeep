import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

/// App Lifecycle Observer that automatically locks the vault
/// if the application remains in the background for more than [lockTimeout].
class AppLockObserver extends WidgetsBindingObserver {
  final WidgetRef? _ref;
  final ProviderContainer? _container;
  final Duration lockTimeout;
  Timer? _lockTimer;
  DateTime? _pausedTime;

  AppLockObserver({
    WidgetRef? ref,
    ProviderContainer? container,
    this.lockTimeout = const Duration(seconds: 30),
  })  : _ref = ref,
        _container = container;

  /// Starts listening to lifecycle changes
  void register() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stops listening to lifecycle changes
  void dispose() {
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedTime = DateTime.now();
      _lockTimer?.cancel();
      _lockTimer = Timer(lockTimeout, () {
        _triggerAutoLock();
      });
    } else if (state == AppLifecycleState.resumed) {
      _lockTimer?.cancel();
      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!);
        if (elapsed >= lockTimeout) {
          _triggerAutoLock();
        }
        _pausedTime = null;
      }
    }
  }

  void _triggerAutoLock() {
    if (_ref != null) {
      final authState = _ref.read(authNotifierProvider);
      if (authState.status == AuthStatus.authenticated) {
        _ref.read(authNotifierProvider.notifier).lockVault();
      }
    } else if (_container != null) {
      final authState = _container.read(authNotifierProvider);
      if (authState.status == AuthStatus.authenticated) {
        _container.read(authNotifierProvider.notifier).lockVault();
      }
    }
  }
}

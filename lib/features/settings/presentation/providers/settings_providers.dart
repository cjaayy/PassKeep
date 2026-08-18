import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/security/security_providers.dart';

/// State representation of user settings & preferences
class SettingsState {
  final bool autoSyncEnabled;
  final ThemeMode themeMode;

  const SettingsState({
    this.autoSyncEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  SettingsState copyWith({
    bool? autoSyncEnabled,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// StateNotifier managing persistent user settings
class SettingsNotifier extends StateNotifier<SettingsState> {
  final FlutterSecureStorage _storage;

  SettingsNotifier({required FlutterSecureStorage storage})
      : _storage = storage,
        super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final syncVal = await _storage.read(key: StorageKeys.autoSyncEnabledKey);
      if (syncVal != null) {
        state = state.copyWith(autoSyncEnabled: syncVal == 'true');
      }

      final themeVal = await _storage.read(key: StorageKeys.themeModeKey);
      if (themeVal != null) {
        ThemeMode mode = ThemeMode.system;
        if (themeVal == 'light') {
          mode = ThemeMode.light;
        } else if (themeVal == 'dark') {
          mode = ThemeMode.dark;
        }
        state = state.copyWith(themeMode: mode);
      }
    } catch (_) {}
  }

  /// Updates the auto-sync preference and persists it to secure storage
  Future<void> setAutoSyncEnabled(bool enabled) async {
    state = state.copyWith(autoSyncEnabled: enabled);
    try {
      await _storage.write(
        key: StorageKeys.autoSyncEnabledKey,
        value: enabled.toString(),
      );
    } catch (_) {}
  }

  /// Updates the app theme mode and persists it to secure storage
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      String strVal = 'system';
      if (mode == ThemeMode.light) {
        strVal = 'light';
      } else if (mode == ThemeMode.dark) {
        strVal = 'dark';
      }
      await _storage.write(
        key: StorageKeys.themeModeKey,
        value: strVal,
      );
    } catch (_) {}
  }
}

/// Provider for [SettingsNotifier]
final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SettingsNotifier(storage: storage);
});

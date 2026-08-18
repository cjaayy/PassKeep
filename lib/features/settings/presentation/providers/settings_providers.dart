import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/security/security_providers.dart';

/// State representation of user settings & preferences
class SettingsState {
  final bool autoSyncEnabled;

  const SettingsState({
    this.autoSyncEnabled = true,
  });

  SettingsState copyWith({
    bool? autoSyncEnabled,
  }) {
    return SettingsState(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
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
      final val = await _storage.read(key: StorageKeys.autoSyncEnabledKey);
      if (val != null) {
        state = state.copyWith(autoSyncEnabled: val == 'true');
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
}

/// Provider for [SettingsNotifier]
final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SettingsNotifier(storage: storage);
});

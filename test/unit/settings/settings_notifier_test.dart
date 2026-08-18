import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/constants/storage_keys.dart';
import 'package:passkeep/features/settings/presentation/providers/settings_providers.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }
}

void main() {
  group('SettingsNotifier Tests', () {
    late FakeSecureStorage storage;

    setUp(() {
      storage = FakeSecureStorage();
    });

    test('initial state defaults autoSyncEnabled to true', () {
      final notifier = SettingsNotifier(storage: storage);
      expect(notifier.state.autoSyncEnabled, isTrue);
    });

    test('setAutoSyncEnabled updates state and writes to storage', () async {
      final notifier = SettingsNotifier(storage: storage);

      await notifier.setAutoSyncEnabled(false);
      expect(notifier.state.autoSyncEnabled, isFalse);
      expect(await storage.read(key: StorageKeys.autoSyncEnabledKey), 'false');

      await notifier.setAutoSyncEnabled(true);
      expect(notifier.state.autoSyncEnabled, isTrue);
      expect(await storage.read(key: StorageKeys.autoSyncEnabledKey), 'true');
    });

    test('loads persisted false setting on startup', () async {
      await storage.write(key: StorageKeys.autoSyncEnabledKey, value: 'false');

      final notifier = SettingsNotifier(storage: storage);
      // Wait for microtask/async _loadSettings to complete
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.autoSyncEnabled, isFalse);
    });
  });
}

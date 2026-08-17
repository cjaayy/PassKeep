import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/auth/presentation/observers/app_lock_observer.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

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
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

class FakeLocalAuth extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => false;

  @override
  Future<bool> isDeviceSupported() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppLockObserver initiates lock timer on pause and triggers lock upon timeout', () async {
    final fakeStorage = FakeSecureStorage();
    final encryptionService = EncryptionService(secureStorage: fakeStorage);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        encryptionServiceProvider.overrideWithValue(encryptionService),
        localAuthProvider.overrideWithValue(FakeLocalAuth()),
      ],
    );

    final authNotifier = container.read(authNotifierProvider.notifier);
    await authNotifier.checkAuthState();
    await authNotifier.setupMasterPin('123456');
    expect(container.read(authNotifierProvider).status, equals(AuthStatus.authenticated));

    final observer = AppLockObserver(
      container: container,
      lockTimeout: const Duration(milliseconds: 50),
    );

    // Simulate app pausing
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);

    // Wait for timeout to trigger lock
    await Future.delayed(const Duration(milliseconds: 80));

    expect(container.read(authNotifierProvider).status, equals(AuthStatus.locked));

    observer.dispose();
  });

  test('AppLockObserver does not lock if app resumes before timeout', () async {
    final fakeStorage = FakeSecureStorage();
    final encryptionService = EncryptionService(secureStorage: fakeStorage);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        encryptionServiceProvider.overrideWithValue(encryptionService),
        localAuthProvider.overrideWithValue(FakeLocalAuth()),
      ],
    );

    final authNotifier = container.read(authNotifierProvider.notifier);
    await authNotifier.checkAuthState();
    await authNotifier.setupMasterPin('123456');
    expect(container.read(authNotifierProvider).status, equals(AuthStatus.authenticated));

    final observer = AppLockObserver(
      container: container,
      lockTimeout: const Duration(milliseconds: 100),
    );

    // Pause then immediately resume after 20ms (before 100ms timeout)
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future.delayed(const Duration(milliseconds: 20));
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

    // Wait past the 100ms timeout
    await Future.delayed(const Duration(milliseconds: 120));

    expect(container.read(authNotifierProvider).status, equals(AuthStatus.authenticated));

    observer.dispose();
  });
}

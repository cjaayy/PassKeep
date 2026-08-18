import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/screens/setup_master_pin_screen.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _storage[key];

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
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }
}

class ThrowingSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      null;

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
    throw Exception('Secure Storage disk full');
  }
}

class FakeLocalAuth extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => true;
  @override
  Future<bool> isDeviceSupported() async => true;
}

void main() {
  testWidgets('SetupMasterPinScreen creates and confirms 6-digit PIN successfully',
      (WidgetTester tester) async {
    final fakeStorage = FakeSecureStorage();
    final encryptionService = EncryptionService(secureStorage: fakeStorage);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        encryptionServiceProvider.overrideWithValue(encryptionService),
        localAuthProvider.overrideWithValue(FakeLocalAuth()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SetupMasterPinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial state: Create Master PIN
    expect(find.text('Create Master PIN'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Enter 6 digits: '1', '2', '3', '4', '5', '6'
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('keypad_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Verify auto-advanced to confirmation screen
    expect(find.text('Confirm Master PIN'), findsOneWidget);
    expect(find.text('Complete Setup'), findsOneWidget);

    // Enter confirmation digits: '1', '2', '3', '4', '5', '6'
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('keypad_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Verify authentication state is authenticated and active key is set
    expect(container.read(authNotifierProvider).status, AuthStatus.authenticated);
    expect(container.read(authNotifierProvider).masterKey, isNotNull);
    expect(encryptionService.hasActiveKey, isTrue);

    container.dispose();
  });

  testWidgets('SetupMasterPinScreen shows error on mismatched confirmation PIN',
      (WidgetTester tester) async {
    final fakeStorage = FakeSecureStorage();
    final encryptionService = EncryptionService(secureStorage: fakeStorage);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        encryptionServiceProvider.overrideWithValue(encryptionService),
        localAuthProvider.overrideWithValue(FakeLocalAuth()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SetupMasterPinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter 6 digits: '1', '2', '3', '4', '5', '6'
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('keypad_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Confirm with mismatched PIN: '6', '5', '4', '3', '2', '1'
    for (final digit in ['6', '5', '4', '3', '2', '1']) {
      await tester.tap(find.byKey(Key('keypad_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('PINs do not match. Please try again.'), findsOneWidget);

    container.dispose();
  });

  testWidgets('SetupMasterPinScreen shows error message if setup fails',
      (WidgetTester tester) async {
    final throwingStorage = ThrowingSecureStorage();
    final encryptionService = EncryptionService(secureStorage: throwingStorage);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(throwingStorage),
        encryptionServiceProvider.overrideWithValue(encryptionService),
        localAuthProvider.overrideWithValue(FakeLocalAuth()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SetupMasterPinScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter 6 digits: '1', '2', '3', '4', '5', '6'
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('keypad_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Confirm 6 digits: '1', '2', '3', '4', '5', '6'
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('keypad_$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to configure Master PIN'), findsWidgets);

    container.dispose();
  });
}

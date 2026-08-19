import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/vault/presentation/widgets/verify_master_pin_sheet.dart';

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
  }) async {
    return _storage[key];
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
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }
}

class FakeLocalAuth extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => false;

  @override
  Future<bool> isDeviceSupported() async => false;
}

void main() {
  testWidgets('VerifyMasterPinSheet verifies correct PIN and unlocks vault session',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeStorage = FakeSecureStorage();
    final encryptionService = EncryptionService(secureStorage: fakeStorage);
    final fakeLocalAuth = FakeLocalAuth();

    final authNotifier = AuthNotifier(
      secureStorage: fakeStorage,
      encryptionService: encryptionService,
      localAuth: fakeLocalAuth,
    );

    // Setup master PIN '123456'
    await authNotifier.setupMasterPin('123456');

    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => authNotifier),
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (_) => const VerifyMasterPinSheet(),
                  );
                },
                child: const Text('Open PIN Prompt'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open PIN Prompt'));
    await tester.pumpAndSettle();

    // Verify UI
    expect(find.text('Enter Master PIN'), findsOneWidget);
    expect(find.text('Authenticate to view encrypted vault entries'), findsOneWidget);

    // Enter correct PIN: 1 2 3 4 5 6
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('verify_keypad_$digit')));
      await tester.pump();
    }

    await tester.pumpAndSettle();

    // Sheet should close and return true
    expect(result, isTrue);
    expect(find.text('Enter Master PIN'), findsNothing);
  });

  testWidgets('VerifyMasterPinSheet shows error on incorrect PIN',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeStorage = FakeSecureStorage();
    final encryptionService = EncryptionService(secureStorage: fakeStorage);
    final fakeLocalAuth = FakeLocalAuth();

    final authNotifier = AuthNotifier(
      secureStorage: fakeStorage,
      encryptionService: encryptionService,
      localAuth: fakeLocalAuth,
    );

    // Setup master PIN '123456'
    await authNotifier.setupMasterPin('123456');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => authNotifier),
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: VerifyMasterPinSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter wrong PIN: 9 9 9 9 9 9
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('verify_keypad_9')));
      await tester.pump();
    }

    await tester.pumpAndSettle();

    // Error message should appear
    expect(find.text('Incorrect Master PIN. Please try again.'), findsOneWidget);
  });
}

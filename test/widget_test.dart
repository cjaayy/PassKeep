import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeep/app.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';

class FakeWidgetSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null; // Returns null so status is uninitialized
}

class FakeWidgetLocalAuth extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => false;

  @override
  Future<bool> isDeviceSupported() async => false;
}

void main() {
  testWidgets('PassKeepApp launches and navigates to WelcomeScreen on uninitialized state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeWidgetSecureStorage()),
          localAuthProvider.overrideWithValue(FakeWidgetLocalAuth()),
        ],
        child: const PassKeepApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PassKeep'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Continue Offline'), findsOneWidget);
  });
}

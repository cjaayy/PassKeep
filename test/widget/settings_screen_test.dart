import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:passkeep/features/settings/presentation/screens/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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
  }) async => _data[key];

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

class FakeSupabaseUserNotifier extends StateNotifier<SupabaseUserState>
    implements SupabaseUserNotifier {
  FakeSupabaseUserNotifier(super.state);

  @override
  Future<bool> signIn({required String email, required String password}) async => true;

  @override
  Future<bool> signUp({required String email, required String password}) async => true;

  @override
  Future<void> signOut() async {
    state = const SupabaseUserState.initial();
  }

  @override
  Future<void> syncLocalSaltToCloud(String salt) async {}
}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  Future<void> checkAuthState() async {}

  @override
  Future<bool> setupMasterPin(String pin) async => true;

  @override
  Future<bool> unlockWithPin(String pin) async => true;

  @override
  Future<bool> unlockWithBiometrics() async => true;

  @override
  void lockVault() {
    state = state.copyWith(status: AuthStatus.locked);
  }

  @override
  void setOfflineOnlyMode(bool isOffline) {
    state = state.copyWith(isOfflineOnlyMode: isOffline);
  }
}

void main() {
  testWidgets('SettingsScreen displays Connect Cloud Account option in Offline-Only Mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          authNotifierProvider.overrideWith(
            (ref) => FakeAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                isOfflineOnlyMode: true,
              ),
            ),
          ),
          supabaseUserProvider.overrideWith(
            (ref) => FakeSupabaseUserNotifier(
              const SupabaseUserState.initial(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Settings Title
    expect(find.text('Settings & Vault'), findsOneWidget);

    // Verify Account & Cloud Sync section is VISIBLE with Offline info and Connect Button
    expect(find.text('ACCOUNT & CLOUD SYNC'), findsOneWidget);
    expect(find.text('Cloud Sync Disabled'), findsOneWidget);
    expect(find.text('Sign In / Connect Cloud Account'), findsOneWidget);

    // Verify other sections remain accessible
    expect(find.text('DATA TRANSFER & BACKUPS'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('SECURITY & ACCESS'), findsOneWidget);
    expect(find.text('ABOUT PASSKEEP'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders Account & Cloud Sync with Auto-Sync toggle when connected',
      (WidgetTester tester) async {
    final testUser = sb.User(
      id: 'test-user-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'alex@passkeep.io',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          authNotifierProvider.overrideWith(
            (ref) => FakeAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                isOfflineOnlyMode: false,
              ),
            ),
          ),
          supabaseUserProvider.overrideWith(
            (ref) => FakeSupabaseUserNotifier(
              SupabaseUserState(user: testUser),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Account & Cloud Sync section is VISIBLE
    expect(find.text('ACCOUNT & CLOUD SYNC'), findsOneWidget);
    expect(find.text('alex@passkeep.io'), findsOneWidget);
    expect(find.text('Cloud Synchronization'), findsOneWidget);
    expect(find.text('Force Push to Cloud'), findsOneWidget);
    expect(find.text('Wipe Remote & Re-sync'), findsOneWidget);

    // Verify Auto-Sync Passwords toggle is VISIBLE and switched on by default
    expect(find.text('Auto-Sync Passwords'), findsOneWidget);
    expect(
      find.text('Automatically upload new or updated items when online'),
      findsOneWidget,
    );

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final switchWidget = tester.widget<Switch>(switchFinder);
    expect(switchWidget.value, isTrue);

    // Tap switch to toggle off
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final toggledSwitch = tester.widget<Switch>(switchFinder);
    expect(toggledSwitch.value, isFalse);
  });
}

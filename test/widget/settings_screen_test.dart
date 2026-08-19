import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:passkeep/features/settings/presentation/screens/settings_screen.dart';
import 'package:passkeep/features/settings/presentation/widgets/change_master_pin_sheet.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';
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

  String validPin = '123456';
  bool updatePinResult = true;

  @override
  Future<void> checkAuthState() async {}

  @override
  Future<bool> setupMasterPin(String pin) async => true;

  @override
  Future<bool> unlockWithPin(String pin) async => true;

  @override
  Future<bool> verifyMasterPin(String pin) async => pin == validPin;

  @override
  Future<bool> updateMasterPin(String currentPin, String newPin) async {
    if (currentPin != validPin) {
      state = state.copyWith(errorMessage: 'Current Master PIN is incorrect.');
      return false;
    }
    if (newPin.length != 6) {
      state = state.copyWith(errorMessage: 'New PIN must be exactly 6 digits');
      return false;
    }
    validPin = newPin;
    return updatePinResult;
  }

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

class FakeLocalDataSource implements IVaultLocalDataSource {
  final List<VaultItem> items = [];

  @override
  Future<List<VaultItem>> getAllVaultItems() async => List.from(items);

  @override
  Future<VaultItem?> getVaultItemById(String id) async =>
      items.firstWhere((i) => i.id == id);

  @override
  Future<void> saveVaultItem(VaultItem item) async => items.add(item);

  @override
  Future<void> deleteVaultItem(String id) async => items.removeWhere((i) => i.id == id);

  @override
  Future<void> clearAll() async => items.clear();
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
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('SECURITY & ACCESS'), findsOneWidget);
    expect(find.text('Change Master PIN'), findsOneWidget);
    expect(find.text('Update your primary vault unlock PIN'), findsOneWidget);
    expect(find.text('ABOUT PASSKEEP'), findsOneWidget);
    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('1.0.0+1'), findsOneWidget);
    // Redundant about tiles are removed
    expect(find.text('Architecture'), findsNothing);
    expect(find.text('Encryption Standard'), findsNothing);
  });

  testWidgets('SettingsScreen streamlines Account & Cloud Sync without Force Push tile',
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
    expect(find.text('Wipe Remote & Re-sync'), findsOneWidget);

    // Verify Force Push tile is REMOVED
    expect(find.text('Force Push to Cloud'), findsNothing);

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

  testWidgets('ChangeMasterPinSheet guides user through 3-step PIN verification and update flow',
      (WidgetTester tester) async {
    final fakeAuth = FakeAuthNotifier(
      const AuthState(status: AuthStatus.authenticated),
    );
    fakeAuth.validPin = '123456';

    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => fakeAuth),
          vaultLocalDataSourceProvider.overrideWithValue(FakeLocalDataSource()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const ChangeMasterPinSheet(),
                  );
                },
                child: const Text('Open Change PIN Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Open Sheet
    await tester.tap(find.text('Open Change PIN Sheet'));
    await tester.pumpAndSettle();

    // Verify Step 1 UI (Verify Current PIN)
    expect(find.text('Verify Current PIN'), findsOneWidget);
    expect(find.text('Enter your current 6-digit Master PIN to continue'), findsOneWidget);

    // Enter wrong PIN (999999)
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.text('9'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Verify error displayed
    expect(find.text('Incorrect current Master PIN. Please try again.'), findsOneWidget);

    // Enter correct PIN (123456)
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Verify Step 2 UI (Create New PIN)
    expect(find.text('Create New PIN'), findsOneWidget);
    expect(find.text('Enter your new 6-digit Master PIN'), findsOneWidget);

    // Enter New PIN (654321)
    for (final digit in ['6', '5', '4', '3', '2', '1']) {
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Verify Step 3 UI (Confirm New PIN)
    expect(find.text('Confirm New PIN'), findsOneWidget);
    expect(find.text('Re-enter your new 6-digit Master PIN to verify'), findsOneWidget);

    // Test back button from Step 3 to Step 2
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Create New PIN'), findsOneWidget);

    // Re-enter New PIN (654321) to proceed to Step 3 again
    for (final digit in ['6', '5', '4', '3', '2', '1']) {
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Confirm New PIN'), findsOneWidget);

    // Enter mismatched PIN (111111)
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('PINs do not match. Please try again.'), findsOneWidget);

    // Enter matching PIN (654321)
    for (final digit in ['6', '5', '4', '3', '2', '1']) {
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Verify dialog popped with true
    expect(result, isTrue);
    expect(fakeAuth.validPin, '654321');
  });

  testWidgets('WipeRemoteConfirmationDialog counts down 10s before enabling confirm button',
      (WidgetTester tester) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                confirmed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const WipeRemoteConfirmationDialog(
                    initialCountdownSeconds: 3, // Use 3s for fast, reliable unit test
                  ),
                );
              },
              child: const Text('Open Wipe Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Wipe Dialog'));
    await tester.pump();

    // Verify dialog content is visible
    expect(find.text('Wipe Remote Vault?'), findsOneWidget);
    expect(find.text('Confirm Wipe (3s)'), findsOneWidget);

    // Verify confirm button is initially DISABLED
    final confirmButtonFinder = find.widgetWithText(ElevatedButton, 'Confirm Wipe (3s)');
    final confirmButton = tester.widget<ElevatedButton>(confirmButtonFinder);
    expect(confirmButton.onPressed, isNull);

    // Advance 1 second
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Confirm Wipe (2s)'), findsOneWidget);

    // Advance 1 second
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Confirm Wipe (1s)'), findsOneWidget);

    // Advance 1 second (countdown finishes)
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Confirm Wipe & Re-sync'), findsOneWidget);

    // Verify confirm button is now ENABLED
    final enabledButtonFinder = find.widgetWithText(ElevatedButton, 'Confirm Wipe & Re-sync');
    final enabledButton = tester.widget<ElevatedButton>(enabledButtonFinder);
    expect(enabledButton.onPressed, isNotNull);

    // Tap confirm button
    await tester.tap(enabledButtonFinder);
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });

  testWidgets('WipeRemoteConfirmationDialog cancel button dismisses dialog immediately',
      (WidgetTester tester) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                confirmed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const WipeRemoteConfirmationDialog(
                    initialCountdownSeconds: 10,
                  ),
                );
              },
              child: const Text('Open Wipe Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Wipe Dialog'));
    await tester.pump();

    expect(find.text('Wipe Remote Vault?'), findsOneWidget);

    // Tap Cancel button immediately while countdown is active
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(find.text('Wipe Remote Vault?'), findsNothing);
  });
}

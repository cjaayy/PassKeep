import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:passkeep/features/auth/presentation/screens/verify_master_pin_screen.dart';
import 'package:passkeep/features/sync/domain/services/vault_sync_service.dart';
import 'package:passkeep/features/sync/presentation/providers/sync_providers.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  String validPin = '123456';
  bool unlockResult = true;

  @override
  Future<void> checkAuthState() async {}

  @override
  Future<bool> setupMasterPin(String pin) async => true;

  @override
  Future<bool> unlockWithPin(String pin) async => true;

  @override
  Future<bool> unlockWithExistingPin(String pin) async {
    if (pin != validPin) {
      state = state.copyWith(errorMessage: 'Incorrect Master PIN. Please try again.');
      return false;
    }
    state = state.copyWith(status: AuthStatus.authenticated, errorMessage: null);
    return unlockResult;
  }

  @override
  Future<bool> verifyMasterPin(String pin) async => pin == validPin;

  @override
  Future<bool> updateMasterPin(String currentPin, String newPin) async => true;

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

  @override
  Future<bool> hasLocalPinConfigured() async => true;

  @override
  void signOut() {
    state = state.copyWith(
      status: AuthStatus.uninitialized,
      clearMasterKey: true,
      isOfflineOnlyMode: false,
    );
  }

  @override
  Future<void> resetSession() async {
    state = state.copyWith(
      status: AuthStatus.uninitialized,
      clearMasterKey: true,
      isOfflineOnlyMode: false,
    );
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

class FakeSyncNotifier extends StateNotifier<SyncState> implements SyncNotifier {
  FakeSyncNotifier() : super(const SyncState());

  int syncCallCount = 0;

  @override
  Future<SyncResult> sync() async {
    syncCallCount++;
    return SyncResult(
      pushedCount: 0,
      pulledCount: 0,
      conflictResolvedCount: 0,
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<SyncResult> migrateAndSync(String userId) async {
    return SyncResult(
      pushedCount: 0,
      pulledCount: 0,
      conflictResolvedCount: 0,
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<SyncResult> forceUploadLocalVault() async {
    return SyncResult(
      pushedCount: 0,
      pulledCount: 0,
      conflictResolvedCount: 0,
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<SyncResult> wipeRemoteAndResync() async {
    return SyncResult(
      pushedCount: 0,
      pulledCount: 0,
      conflictResolvedCount: 0,
      syncedAt: DateTime.now(),
    );
  }
}

void main() {
  testWidgets('VerifyMasterPinScreen renders UI elements and verifies existing PIN successfully',
      (WidgetTester tester) async {
    final fakeAuth = FakeAuthNotifier(
      const AuthState(status: AuthStatus.uninitialized),
    );
    final fakeSync = FakeSyncNotifier();
    final user = sb.User(
      id: 'u1',
      appMetadata: {},
      userMetadata: {'master_pin_salt': 'salt123'},
      aud: 'auth',
      createdAt: DateTime.now().toIso8601String(),
      email: 'user@example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => fakeAuth),
          syncNotifierProvider.overrideWith((ref) => fakeSync),
          vaultLocalDataSourceProvider.overrideWithValue(FakeLocalDataSource()),
          supabaseUserProvider.overrideWith(
            (ref) => FakeSupabaseUserNotifier(SupabaseUserState(user: user)),
          ),
        ],
        child: const MaterialApp(
          home: VerifyMasterPinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Enter Master PIN'), findsOneWidget);
    expect(
      find.text('Enter your existing Master PIN to unlock and decrypt your vault'),
      findsOneWidget,
    );
    expect(find.text('user@example.com'), findsOneWidget);

    // Enter incorrect PIN (999999)
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.text('9'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Verify error message shown
    expect(find.text('Incorrect Master PIN. Please try again.'), findsOneWidget);

    // Enter correct PIN (123456)
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Verify authenticated and sync called
    expect(fakeAuth.state.status, AuthStatus.authenticated);
    expect(fakeSync.syncCallCount, 1);
  });

  testWidgets('VerifyMasterPinScreen shows reset session dialog and resets on confirm',
      (WidgetTester tester) async {
    final fakeLocal = FakeLocalDataSource();
    final fakeSync = FakeSyncNotifier();
    final fakeAuth = FakeAuthNotifier(
      const AuthState(status: AuthStatus.locked),
    );
    final fakeSupabase = FakeSupabaseUserNotifier(
      const SupabaseUserState(
        user: sb.User(
          id: 'user-789',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01',
          email: 'lockedout@passkeep.io',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
          syncNotifierProvider.overrideWith((ref) => fakeSync),
          authNotifierProvider.overrideWith((ref) => fakeAuth),
          supabaseUserProvider.overrideWith((ref) => fakeSupabase),
        ],
        child: const MaterialApp(
          home: VerifyMasterPinScreen(),
        ),
      ),
    );

    final resetBtn = find.text('Having trouble? Reset Session / Sign Out');
    expect(resetBtn, findsOneWidget);
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    // Verify dialog
    expect(find.text('Reset Session / Sign Out'), findsOneWidget);
    expect(
      find.text('This will sign you out and clear local cached session keys. Your cloud data remains safe in Supabase.'),
      findsOneWidget,
    );

    // Tap Reset & Sign Out
    final confirmBtn = find.widgetWithText(ElevatedButton, 'Reset & Sign Out');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Verify auth status reset to uninitialized and supabase user signed out
    expect(fakeAuth.state.status, AuthStatus.uninitialized);
    expect(fakeSupabase.state.user, isNull);
  });
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


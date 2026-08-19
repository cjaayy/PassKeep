import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';

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

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  Future<void> checkAuthState() async {}

  @override
  Future<bool> setupMasterPin(String pin) async => true;

  @override
  Future<bool> unlockWithPin(String pin) async => true;

  @override
  Future<bool> unlockWithExistingPin(String pin) async => true;

  @override
  Future<bool> verifyMasterPin(String pin) async => true;

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

void main() {
  testWidgets('DashboardScreen starts directly with VAULT OVERVIEW and renders quick actions without duplicate header',
      (WidgetTester tester) async {
    final fakeLocal = FakeLocalDataSource();
    fakeLocal.items.addAll([
      VaultItem(
        id: 'pw-1',
        title: 'Google',
        type: VaultType.password,
        usernameEncrypted: 'user',
        passwordEncrypted: 'pass',
        iv: 'iv1',
        category: 'Work',
        updatedAt: DateTime.now(),
      ),
      VaultItem(
        id: 'card-1',
        title: 'BPI Visa',
        type: VaultType.card,
        usernameEncrypted: 'holder',
        passwordEncrypted: 'number',
        iv: 'iv2',
        category: 'Cards',
        accountNumber: '•••• •••• •••• 1234',
        cardDetailsEnc: '{}',
        updatedAt: DateTime.now(),
      ),
    ]);

    bool navigatedToPasswords = false;
    bool navigatedToCards = false;

    final container = ProviderContainer(
      overrides: [
        vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
        authNotifierProvider.overrideWith(
          (ref) => FakeAuthNotifier(
            const AuthState(
              status: AuthStatus.authenticated,
              isOfflineOnlyMode: true,
            ),
          ),
        ),
      ],
    );

    // Explicitly load items
    await container.read(vaultNotifierProvider.notifier).loadVaultItems();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DashboardScreen(
            onNavigateToPasswords: () => navigatedToPasswords = true,
            onNavigateToCards: () => navigatedToCards = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify duplicate header banner is removed
    expect(find.text('PassKeep Dashboard'), findsNothing);

    // Verify Vault Overview counts (Total = 2, Passwords = 1, Cards = 1)
    expect(find.text('VAULT OVERVIEW'), findsOneWidget);
    expect(find.text('Total Encrypted Items'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // Total
    expect(find.text('Passwords'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);

    // Verify Quick Actions
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('New Payment Card'), findsOneWidget);
    expect(find.text('Password Generator'), findsOneWidget);

    // Verify RefreshIndicator exists
    expect(find.byType(RefreshIndicator), findsOneWidget);

    // Test shortcut taps
    await tester.tap(find.text('Passwords'));
    await tester.pumpAndSettle();
    expect(navigatedToPasswords, isTrue);

    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(navigatedToCards, isTrue);
  });
}

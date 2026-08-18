import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/utils/card_brand_helper.dart';
import 'package:passkeep/features/vault/data/models/card_details.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_state.dart';

void main() {
  group('VaultItem Model Tests', () {
    final testDate = DateTime.parse('2026-08-17T12:00:00.000Z');

    final testItem = VaultItem(
      id: 'uuid-1234-5678',
      title: 'GitHub Account',
      usernameEncrypted: 'enc_user_base64_abc==',
      passwordEncrypted: 'enc_pass_base64_xyz==',
      iv: 'iv_base64_vector==',
      category: 'Developer',
      notes: 'Contains 2FA backup codes',
      isSynced: false,
      updatedAt: testDate,
    );

    test('should instantiate VaultItem with all properties correctly', () {
      expect(testItem.id, 'uuid-1234-5678');
      expect(testItem.title, 'GitHub Account');
      expect(testItem.usernameEncrypted, 'enc_user_base64_abc==');
      expect(testItem.passwordEncrypted, 'enc_pass_base64_xyz==');
      expect(testItem.iv, 'iv_base64_vector==');
      expect(testItem.category, 'Developer');
      expect(testItem.notes, 'Contains 2FA backup codes');
      expect(testItem.isSynced, false);
      expect(testItem.updatedAt, testDate);
      expect(testItem.isLogin, true);
      expect(testItem.isCard, false);
    });

    test('should return a modified copy when copyWith is called', () {
      final updated = testItem.copyWith(
        title: 'GitHub Enterprise',
        isSynced: true,
      );

      expect(updated.id, testItem.id);
      expect(updated.title, 'GitHub Enterprise');
      expect(updated.isSynced, true);
      expect(updated.usernameEncrypted, testItem.usernameEncrypted);
    });

    test('should serialize to Map and deserialize from Map correctly', () {
      final map = testItem.toMap();
      expect(map['id'], 'uuid-1234-5678');
      expect(map['title'], 'GitHub Account');
      expect(map['username_encrypted'], 'enc_user_base64_abc==');
      expect(map['password_encrypted'], 'enc_pass_base64_xyz==');
      expect(map['iv'], 'iv_base64_vector==');
      expect(map['category'], 'Developer');
      expect(map['notes'], 'Contains 2FA backup codes');
      expect(map['is_synced'], false);
      expect(map['updated_at'], testDate.toIso8601String());
      expect(map['type'], 'login');

      final fromMapItem = VaultItem.fromMap(map);
      expect(fromMapItem, equals(testItem));
    });

    test('should serialize to JSON and deserialize from JSON correctly', () {
      final jsonStr = testItem.toJson();
      final fromJsonItem = VaultItem.fromJson(jsonStr);

      expect(fromJsonItem, equals(testItem));
      expect(fromJsonItem.hashCode, equals(testItem.hashCode));
    });

    test('should instantiate and serialize payment card item correctly', () {
      final cardItem = VaultItem(
        id: 'card-1',
        title: 'BPI Visa Signature',
        type: 'card',
        usernameEncrypted: 'enc_holder',
        passwordEncrypted: 'enc_number',
        cardDetailsEnc: 'enc_card_details_payload',
        iv: 'iv_val',
        category: 'Finance',
        accountNumber: '•••• •••• •••• 1234',
        updatedAt: testDate,
      );

      expect(cardItem.isCard, isTrue);
      expect(cardItem.isLogin, isFalse);

      final map = cardItem.toMap();
      expect(map['type'], 'card');
      expect(map['card_details_enc'], 'enc_card_details_payload');

      final fromMap = VaultItem.fromMap(map);
      expect(fromMap.isCard, isTrue);
      expect(fromMap.cardDetailsEnc, 'enc_card_details_payload');
    });

    test('should verify VaultItemAdapter typeId is 0', () {
      final adapter = VaultItemAdapter();
      expect(adapter.typeId, 0);
    });
  });

  group('CardBrandHelper & CardDetails Tests', () {
    test('detects card brands correctly from leading digits', () {
      expect(CardBrandHelper.detectBrand('4123 4567 8901 2345'), CardBrand.visa);
      expect(CardBrandHelper.detectBrand('5123 4567 8901 2345'), CardBrand.mastercard);
      expect(CardBrandHelper.detectBrand('3412 3456 7890 123'), CardBrand.amex);
      expect(CardBrandHelper.detectBrand('6011 0000 0000 0000'), CardBrand.discover);
      expect(CardBrandHelper.detectBrand('3528 0000 0000 0000'), CardBrand.jcb);
      expect(CardBrandHelper.detectBrand('3512 0000 0000 0000'), CardBrand.jcb);
      expect(CardBrandHelper.detectBrand('6200 0000 0000 0000'), CardBrand.unionPay);
      expect(CardBrandHelper.detectBrand(''), CardBrand.generic);
    });

    test('detectCardNetwork matches detectBrand for all networks', () {
      expect(CardBrandHelper.detectCardNetwork('4000 0000 0000 0000'), CardNetwork.visa);
      expect(CardBrandHelper.detectCardNetwork('5200 0000 0000 0000'), CardNetwork.mastercard);
      expect(CardBrandHelper.detectCardNetwork('3700 0000 0000 000'), CardNetwork.amex);
      expect(CardBrandHelper.detectCardNetwork('3500 0000 0000 0000'), CardNetwork.jcb);
    });

    test('buildBadge returns valid widget for all card brands', () {
      for (final brand in CardBrand.values) {
        final badge = brand.buildBadge();
        expect(badge, isNotNull);
      }
    });

    test('CardDetails masks card numbers and extracts last 4 correctly', () {
      const card = CardDetails(
        cardholderName: 'Juan Dela Cruz',
        cardNumber: '4123 4567 8901 2345',
        expiryDate: '12/28',
        cvv: '123',
      );

      expect(card.last4, '2345');
      expect(card.maskedCardNumber, '•••• •••• •••• 2345');
      expect(card.brand, CardBrand.visa);

      final jsonStr = card.toJson();
      final fromJson = CardDetails.fromJson(jsonStr);
      expect(fromJson.cardholderName, 'Juan Dela Cruz');
      expect(fromJson.cardNumber, '4123 4567 8901 2345');
      expect(fromJson.expiryDate, '12/28');
      expect(fromJson.cvv, '123');
    });
  });

  group('VaultState Type Isolation Tests', () {
    test('strictly separates Password and Card with identical titles', () {
      final passwordItem = VaultItem(
        id: 'pw-1',
        title: 'Maribank',
        type: VaultType.password,
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'enc_pass',
        iv: 'iv_1',
        category: 'Finance',
        updatedAt: DateTime.now(),
      );

      final cardItem = VaultItem(
        id: 'card-1',
        title: 'Maribank',
        type: VaultType.card,
        usernameEncrypted: 'enc_holder',
        passwordEncrypted: 'enc_num',
        iv: 'iv_2',
        category: 'Cards',
        cardDetailsEnc: '{"cardNumber":"4123456789012345"}',
        updatedAt: DateTime.now(),
      );

      final state = VaultState(
        status: VaultStatus.success,
        allItems: [passwordItem, cardItem],
        filteredItems: [passwordItem, cardItem],
        selectedCategory: 'All',
      );

      // Verify passwords separation
      expect(state.allPasswordItems.length, 1);
      expect(state.allPasswordItems.first.id, 'pw-1');
      expect(state.filteredPasswordItems.length, 1);
      expect(state.groupedPasswordItems.length, 1);
      expect(state.groupedPasswordItems.first.count, 1);
      expect(state.groupedPasswordItems.first.items.first.id, 'pw-1');

      // Verify cards separation
      expect(state.allCardItems.length, 1);
      expect(state.allCardItems.first.id, 'card-1');
      expect(state.filteredCardItems.length, 1);
      expect(state.filteredCardItems.first.id, 'card-1');
    });

    test('category filter isolates passwords and does NOT leak into cards tab', () {
      final passwordItem = VaultItem(
        id: 'pw-1',
        title: 'Maribank',
        type: VaultType.password,
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'enc_pass',
        iv: 'iv_1',
        category: 'Personal',
        updatedAt: DateTime.now(),
      );

      final cardItem = VaultItem(
        id: 'card-1',
        title: 'Maribank Debit',
        type: VaultType.card,
        usernameEncrypted: 'enc_holder',
        passwordEncrypted: 'enc_num',
        iv: 'iv_2',
        category: 'Cards',
        cardDetailsEnc: '{"cardNumber":"4123456789012345"}',
        updatedAt: DateTime.now(),
      );

      // User selects category 'Work' (which matches 0 passwords)
      final state = VaultState(
        status: VaultStatus.success,
        allItems: [passwordItem, cardItem],
        filteredItems: [cardItem],
        selectedCategory: 'Work',
      );

      // Passwords list is empty because category is Work
      expect(state.filteredPasswordItems.isEmpty, isTrue);
      expect(state.groupedPasswordItems.isEmpty, isTrue);

      // Cards list is STILL INTACT because category filter does not apply to cards
      expect(state.filteredCardItems.length, 1);
      expect(state.filteredCardItems.first.id, 'card-1');
    });
  });
}

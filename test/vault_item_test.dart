import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';

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

      final fromMapItem = VaultItem.fromMap(map);
      expect(fromMapItem, equals(testItem));
    });

    test('should serialize to JSON and deserialize from JSON correctly', () {
      final jsonStr = testItem.toJson();
      final fromJsonItem = VaultItem.fromJson(jsonStr);

      expect(fromJsonItem, equals(testItem));
      expect(fromJsonItem.hashCode, equals(testItem.hashCode));
    });

    test('should verify VaultItemAdapter typeId is 0', () {
      final adapter = VaultItemAdapter();
      expect(adapter.typeId, 0);
    });
  });
}

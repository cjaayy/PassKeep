import 'dart:convert';
import 'package:hive/hive.dart';

part 'vault_item.g.dart';

/// Constants for Vault item types
abstract class VaultType {
  static const String login = 'login';
  static const String password = 'login';
  static const String card = 'card';
}

/// Hive Type Model representing an encrypted Vault entry.
///
/// Under Zero-Knowledge architecture:
/// - [title], [category], [accountNumber] & [type] remain readable for fast local indexing/searching.
/// - [usernameEncrypted], [passwordEncrypted], [notes] & [cardDetailsEnc] are encrypted with AES-CBC.
/// - [iv] holds the base64-encoded Initialization Vector specific to this item's encryption session.
@HiveType(typeId: 0)
class VaultItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String usernameEncrypted;

  @HiveField(3)
  final String passwordEncrypted;

  @HiveField(4)
  final String iv;

  @HiveField(5)
  final String category;

  @HiveField(6)
  final String? notes;

  @HiveField(7)
  final bool isSynced;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  final String? accountNumber;

  @HiveField(10)
  final String type; // 'login' | 'card'

  @HiveField(11)
  final String? cardDetailsEnc;

  @HiveField(12)
  final String? username;

  @HiveField(13)
  final String? email;

  @HiveField(14)
  final String? phoneNumber;

  @HiveField(15)
  final String? pinEncrypted;

  @HiveField(16)
  final String? qrCodeBase64;

  VaultItem({
    required this.id,
    required this.title,
    this.usernameEncrypted = '',
    this.passwordEncrypted = '',
    required this.iv,
    required this.category,
    this.notes,
    this.isSynced = false,
    required this.updatedAt,
    this.accountNumber,
    this.type = 'login',
    this.cardDetailsEnc,
    this.username,
    this.email,
    this.phoneNumber,
    this.pinEncrypted,
    this.qrCodeBase64,
  });

  bool get isCard => type == 'card';
  bool get isLogin => type == 'login';
  bool get hasQrCode => qrCodeBase64 != null && qrCodeBase64!.isNotEmpty;

  /// Creates a copy of this [VaultItem] with updated properties.
  VaultItem copyWith({
    String? id,
    String? title,
    String? usernameEncrypted,
    String? passwordEncrypted,
    String? iv,
    String? category,
    String? notes,
    bool? isSynced,
    DateTime? updatedAt,
    String? accountNumber,
    bool clearAccountNumber = false,
    String? type,
    String? cardDetailsEnc,
    bool clearCardDetails = false,
    String? username,
    bool clearUsername = false,
    String? email,
    bool clearEmail = false,
    String? phoneNumber,
    bool clearPhoneNumber = false,
    String? pinEncrypted,
    bool clearPinEncrypted = false,
    String? qrCodeBase64,
    bool clearQrCode = false,
  }) {
    return VaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      usernameEncrypted: usernameEncrypted ?? this.usernameEncrypted,
      passwordEncrypted: passwordEncrypted ?? this.passwordEncrypted,
      iv: iv ?? this.iv,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      accountNumber: clearAccountNumber ? null : (accountNumber ?? this.accountNumber),
      type: type ?? this.type,
      cardDetailsEnc: clearCardDetails ? null : (cardDetailsEnc ?? this.cardDetailsEnc),
      username: clearUsername ? null : (username ?? this.username),
      email: clearEmail ? null : (email ?? this.email),
      phoneNumber: clearPhoneNumber ? null : (phoneNumber ?? this.phoneNumber),
      pinEncrypted: clearPinEncrypted ? null : (pinEncrypted ?? this.pinEncrypted),
      qrCodeBase64: clearQrCode ? null : (qrCodeBase64 ?? this.qrCodeBase64),
    );
  }

  /// Returns the primary display identifier for this vault item:
  /// 1. Explicit username (if non-empty)
  /// 2. Decrypted username (if non-empty)
  /// 3. Email (if non-empty)
  /// 4. Account number (if non-empty)
  /// 5. Phone number (if non-empty)
  /// 6. Masked placeholder
  String getPrimaryIdentifier({String? decryptedUsername}) {
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim();
    }
    final user = decryptedUsername?.trim() ?? '';
    if (user.isNotEmpty) {
      return user;
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }
    final acc = accountNumber?.trim() ?? '';
    if (acc.isNotEmpty) {
      return acc;
    }
    if (phoneNumber != null && phoneNumber!.trim().isNotEmpty) {
      return phoneNumber!.trim();
    }
    if (usernameEncrypted.isNotEmpty || (cardDetailsEnc != null && cardDetailsEnc!.isNotEmpty)) {
      return isCard ? '•••• ••••' : '••••••••';
    }
    return 'No identifier';
  }

  /// Converts this [VaultItem] into a Map for local serialization / JSON backup.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'email': email,
      'account_number': accountNumber,
      'phone_number': phoneNumber,
      'username_encrypted': usernameEncrypted,
      'password_encrypted': passwordEncrypted,
      'pin_encrypted': pinEncrypted,
      'qr_code_base64': qrCodeBase64,
      'iv': iv,
      'category': category,
      'notes': notes,
      'is_synced': isSynced,
      'updated_at': updatedAt.toIso8601String(),
      'type': type,
      'card_details_enc': cardDetailsEnc,
    };
  }

  /// Converts this [VaultItem] into a Supabase PostgreSQL payload.
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'email': email,
      'account_number': accountNumber,
      'phone_number': phoneNumber,
      'username_enc': usernameEncrypted,
      'password_enc': passwordEncrypted,
      'pin_enc': pinEncrypted,
      'qr_code_enc': qrCodeBase64,
      'iv': iv,
      'category': category,
      'notes': notes,
      'is_deleted': false,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'type': type,
      'card_details_enc': cardDetailsEnc,
    };
  }

  /// Creates a [VaultItem] instance from a Map (supporting local, JSON, and Supabase formats).
  factory VaultItem.fromMap(Map<String, dynamic> map) {
    return VaultItem(
      id: map['id'] as String,
      title: map['title'] as String,
      username: (map['username']) as String?,
      email: (map['email']) as String?,
      accountNumber: (map['account_number'] ?? map['accountNumber']) as String?,
      phoneNumber: (map['phone_number'] ?? map['phoneNumber']) as String?,
      usernameEncrypted: (map['username_enc'] ??
          map['username_encrypted'] ??
          map['usernameEncrypted'] ??
          '') as String,
      passwordEncrypted: (map['password_enc'] ??
          map['password_encrypted'] ??
          map['passwordEncrypted'] ??
          '') as String,
      pinEncrypted: (map['pin_enc'] ??
          map['pin_encrypted'] ??
          map['pinEncrypted']) as String?,
      qrCodeBase64: (map['qr_code_enc'] ??
          map['qr_code_base64'] ??
          map['qrCodeBase64']) as String?,
      iv: map['iv'] as String,
      category: (map['category'] as String?) ?? 'General',
      notes: map['notes'] as String?,
      isSynced: (map['is_synced'] ?? map['isSynced'] ?? false) as bool,
      updatedAt: DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String),
      type: (map['type'] as String?) ?? 'login',
      cardDetailsEnc: (map['card_details_enc'] ?? map['cardDetailsEnc']) as String?,
    );
  }

  /// Converts this [VaultItem] to a JSON string representation.
  String toJson() => json.encode(toMap());

  /// Creates a [VaultItem] from a JSON string.
  factory VaultItem.fromJson(String source) =>
      VaultItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'VaultItem(id: $id, title: $title, type: $type, category: $category, account: $accountNumber, isSynced: $isSynced, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VaultItem &&
        other.id == id &&
        other.title == title &&
        other.usernameEncrypted == usernameEncrypted &&
        other.passwordEncrypted == passwordEncrypted &&
        other.iv == iv &&
        other.category == category &&
        other.notes == notes &&
        other.isSynced == isSynced &&
        other.updatedAt == updatedAt &&
        other.accountNumber == accountNumber &&
        other.type == type &&
        other.cardDetailsEnc == cardDetailsEnc &&
        other.username == username &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.pinEncrypted == pinEncrypted &&
        other.qrCodeBase64 == qrCodeBase64;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        usernameEncrypted.hashCode ^
        passwordEncrypted.hashCode ^
        iv.hashCode ^
        category.hashCode ^
        notes.hashCode ^
        isSynced.hashCode ^
        updatedAt.hashCode ^
        accountNumber.hashCode ^
        type.hashCode ^
        cardDetailsEnc.hashCode ^
        username.hashCode ^
        email.hashCode ^
        phoneNumber.hashCode ^
        pinEncrypted.hashCode ^
        qrCodeBase64.hashCode;
  }
}

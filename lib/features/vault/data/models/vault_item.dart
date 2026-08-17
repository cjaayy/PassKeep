import 'dart:convert';
import 'package:hive/hive.dart';

part 'vault_item.g.dart';

/// Hive Type Model representing an encrypted Vault entry.
///
/// Under Zero-Knowledge architecture:
/// - [title] & [category] can remain readable for fast local indexing/searching.
/// - [usernameEncrypted], [passwordEncrypted], and [notes] are encrypted with AES-GCM/CBC.
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

  VaultItem({
    required this.id,
    required this.title,
    required this.usernameEncrypted,
    required this.passwordEncrypted,
    required this.iv,
    required this.category,
    this.notes,
    this.isSynced = false,
    required this.updatedAt,
  });

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
    );
  }

  /// Converts this [VaultItem] into a Map for local serialization / JSON backup.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username_encrypted': usernameEncrypted,
      'password_encrypted': passwordEncrypted,
      'iv': iv,
      'category': category,
      'notes': notes,
      'is_synced': isSynced,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts this [VaultItem] into a Supabase PostgreSQL payload.
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'title': title,
      'username_enc': usernameEncrypted,
      'password_enc': passwordEncrypted,
      'iv': iv,
      'category': category,
      'notes': notes,
      'is_deleted': false,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Creates a [VaultItem] instance from a Map (supporting local, JSON, and Supabase formats).
  factory VaultItem.fromMap(Map<String, dynamic> map) {
    return VaultItem(
      id: map['id'] as String,
      title: map['title'] as String,
      usernameEncrypted: (map['username_enc'] ??
          map['username_encrypted'] ??
          map['usernameEncrypted']) as String,
      passwordEncrypted: (map['password_enc'] ??
          map['password_encrypted'] ??
          map['passwordEncrypted']) as String,
      iv: map['iv'] as String,
      category: (map['category'] as String?) ?? 'General',
      notes: map['notes'] as String?,
      isSynced: (map['is_synced'] ?? map['isSynced'] ?? false) as bool,
      updatedAt: DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String),
    );
  }

  /// Converts this [VaultItem] to a JSON string representation.
  String toJson() => json.encode(toMap());

  /// Creates a [VaultItem] from a JSON string.
  factory VaultItem.fromJson(String source) =>
      VaultItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'VaultItem(id: $id, title: $title, category: $category, isSynced: $isSynced, updatedAt: $updatedAt)';
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
        other.updatedAt == updatedAt;
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
        updatedAt.hashCode;
  }
}

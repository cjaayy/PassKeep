/// Storage & Database Constants for PassKeep
abstract final class StorageKeys {
  /// Hive Box name for storing encrypted vault items
  static const String vaultBoxName = 'passkeep_vault_box';

  /// Secure Storage key for the master encryption key derived via PBKDF2/Argon2
  static const String masterKeyStorageKey = 'passkeep_master_key';

  /// Secure Storage key for the master PIN salt
  static const String masterPinSaltKey = 'passkeep_master_pin_salt';

  /// Secure Storage key for the master PIN verification hash
  static const String masterPinHashKey = 'passkeep_master_pin_hash';

  /// Secure Storage key for biometric auth token / state
  static const String biometricTokenKey = 'passkeep_biometric_token';

  /// Secure Storage key for auto-sync enabled preference
  static const String autoSyncEnabledKey = 'passkeep_auto_sync_enabled';

  /// Hive Type ID constants
  static const int vaultItemTypeId = 0;
}

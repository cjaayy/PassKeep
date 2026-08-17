import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

/// Provider for [FlutterSecureStorage] instance
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Provider for the singleton-scoped [EncryptionService]
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return EncryptionService(secureStorage: secureStorage);
});

/// State provider for tracking the currently unlocked Master Key (Base64) in the session
final activeMasterKeyProvider = StateProvider<String?>((ref) => null);

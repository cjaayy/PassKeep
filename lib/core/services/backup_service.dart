import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/vault/data/datasources/vault_local_datasource.dart';
import '../../features/vault/data/models/vault_item.dart';
import '../../features/vault/presentation/providers/vault_providers.dart';
import '../errors/failures.dart';
import '../security/encryption_service.dart';
import '../security/security_providers.dart';

/// Service managing client-side Zero-Knowledge encrypted vault backups and restores.
class BackupService {
  final IVaultLocalDataSource _localDataSource;
  final EncryptionService _encryptionService;

  BackupService({
    required IVaultLocalDataSource localDataSource,
    required EncryptionService encryptionService,
  })  : _localDataSource = localDataSource,
        _encryptionService = encryptionService;

  /// Creates a serialized, AES-256 encrypted backup envelope of all local vault items.
  Future<String> createEncryptedBackupPayload() async {
    try {
      final items = await _localDataSource.getAllVaultItems();
      final itemsJson = items.map((item) => item.toMap()).toList();
      final serializedPayload = jsonEncode(itemsJson);

      final encryptionResult = _encryptionService.encrypt(serializedPayload);

      final backupEnvelope = {
        'app': 'PassKeep',
        'format': 'passkeep-encrypted-backup',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'itemCount': items.length,
        'cipherText': encryptionResult.cipherTextBase64,
        'iv': encryptionResult.ivBase64,
      };

      return jsonEncode(backupEnvelope);
    } on EncryptionFailure catch (e) {
      throw BackupFailure('Encryption failed during backup export: ${e.message}');
    } catch (e) {
      if (e is Failure) rethrow;
      throw BackupFailure('Failed to generate encrypted backup: ${e.toString()}');
    }
  }

  /// Generates a `.passkeep` encrypted archive and triggers the native system share/save dialog.
  Future<String> exportVaultDataToFile() async {
    try {
      final payload = await createEncryptedBackupPayload();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/passkeep_backup_$timestamp.passkeep';
      final file = File(filePath);

      await file.writeAsString(payload, flush: true);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'PassKeep Encrypted Backup',
        text: 'PassKeep Zero-Knowledge Encrypted Vault Backup',
      );

      return filePath;
    } catch (e) {
      if (e is Failure) rethrow;
      throw BackupFailure('Export failed: ${e.toString()}');
    }
  }

  /// Restores vault items from an encrypted backup payload string and saves them to local storage.
  Future<int> importVaultDataFromPayload(String payload) async {
    try {
      final Map<String, dynamic> envelope = jsonDecode(payload) as Map<String, dynamic>;

      if (!envelope.containsKey('cipherText') || !envelope.containsKey('iv')) {
        throw const BackupFailure('Invalid backup file format: missing encryption headers.');
      }

      final cipherText = envelope['cipherText'] as String;
      final iv = envelope['iv'] as String;

      final decryptedJson = _encryptionService.decrypt(
        cipherTextBase64: cipherText,
        ivBase64: iv,
      );

      final dynamic decodedList = jsonDecode(decryptedJson);
      if (decodedList is! List) {
        throw const BackupFailure('Malformed backup payload structure.');
      }

      int restoredCount = 0;
      for (final rawItem in decodedList) {
        if (rawItem is Map<String, dynamic>) {
          final item = VaultItem.fromMap(rawItem);
          // Mark as unsynced so that restored items will sync to remote if connected
          await _localDataSource.saveVaultItem(item.copyWith(isSynced: false));
          restoredCount++;
        }
      }

      return restoredCount;
    } on DecryptionFailure catch (e) {
      throw BackupFailure('Decryption failed during backup restore: ${e.message}');
    } catch (e) {
      if (e is Failure) rethrow;
      throw BackupFailure('Failed to import backup: ${e.toString()}');
    }
  }

  /// Reads a `.passkeep` file from storage and imports its contents.
  Future<int> importVaultDataFromFile(File file) async {
    try {
      final content = await file.readAsString();
      return await importVaultDataFromPayload(content);
    } catch (e) {
      if (e is Failure) rethrow;
      throw BackupFailure('Failed to read backup file: ${e.toString()}');
    }
  }

  /// Prompts the user to pick a `.passkeep` or JSON backup file and restores vault items.
  Future<int?> importVaultDataFromFilePicker() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        return await importVaultDataFromFile(file);
      }
      return null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw BackupFailure('File selection failed: ${e.toString()}');
    }
  }
}

/// Provider for [BackupService]
final backupServiceProvider = Provider<BackupService>((ref) {
  final localDataSource = ref.watch(vaultLocalDataSourceProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);

  return BackupService(
    localDataSource: localDataSource,
    encryptionService: encryptionService,
  );
});

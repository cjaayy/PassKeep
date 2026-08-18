import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../vault/data/models/vault_item.dart';

/// Abstract interface for remote Supabase Vault sync operations.
abstract class IVaultRemoteDataSource {
  /// Fetches all active (non-deleted) remote vault items for the authenticated user.
  Future<List<VaultItem>> fetchRemoteItems();

  /// Upserts (inserts or updates) a vault item in the remote database.
  Future<void> upsertRemoteItem(VaultItem item);

  /// Bulk upserts multiple vault items in the remote database.
  Future<void> upsertRemoteItems(List<VaultItem> items);

  /// Soft deletes a remote vault item by setting `is_deleted = true`.
  Future<void> deleteRemoteItem(String id);
}

/// Implementation of [IVaultRemoteDataSource] using Supabase.
class VaultRemoteDataSource implements IVaultRemoteDataSource {
  final SupabaseClient? _client;

  VaultRemoteDataSource({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase {
    if (_client != null) return _client;
    return Supabase.instance.client;
  }

  static const String _tableName = 'vault_items';

  @override
  Future<List<VaultItem>> fetchRemoteItems() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('is_deleted', false);

      final List<dynamic> records = response as List<dynamic>;
      return records
          .map((json) => VaultItem.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw SyncFailure('Failed to fetch remote vault items from Supabase: ${e.toString()}');
    }
  }

  @override
  Future<void> upsertRemoteItem(VaultItem item) async {
    try {
      await _supabase
          .from(_tableName)
          .upsert(item.toSupabaseMap());
    } catch (e) {
      if (e is Failure) rethrow;
      throw SyncFailure('Failed to upsert remote vault item (${item.id}): ${e.toString()}');
    }
  }

  @override
  Future<void> upsertRemoteItems(List<VaultItem> items) async {
    if (items.isEmpty) return;
    try {
      final payload = items.map((item) => item.toSupabaseMap()).toList();
      await _supabase
          .from(_tableName)
          .upsert(payload);
    } catch (e) {
      if (e is Failure) rethrow;
      throw SyncFailure('Failed to bulk upsert remote vault items: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteRemoteItem(String id) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'is_deleted': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      if (e is Failure) rethrow;
      throw SyncFailure('Failed to delete remote vault item ($id): ${e.toString()}');
    }
  }
}

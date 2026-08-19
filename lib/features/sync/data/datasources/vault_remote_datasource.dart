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

  /// Hard deletes all remote vault items for the authenticated user.
  Future<void> wipeRemoteVault();
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

  Never _handleSupabaseError(dynamic e, String action) {
    if (e is Failure) throw e;
    if (e is PostgrestException) {
      final msg = e.message;
      final code = e.code ?? '';
      if (code == 'PGRST204' ||
          msg.toLowerCase().contains('schema cache') ||
          msg.toLowerCase().contains('could not find the') ||
          msg.toLowerCase().contains('column')) {
        throw SyncFailure(
          'Supabase schema out of date ($code: $msg). Please execute the migration SQL in your Supabase SQL Editor to add missing columns (email, account_number, phone_number, pin_enc, card_details_enc).',
        );
      }
      throw SyncFailure('Supabase error ($code): $msg');
    }
    throw SyncFailure('Failed to $action: ${e.toString()}');
  }

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
      _handleSupabaseError(e, 'fetch remote vault items');
    }
  }

  @override
  Future<void> upsertRemoteItem(VaultItem item) async {
    try {
      await _supabase
          .from(_tableName)
          .upsert(item.toSupabaseMap());
    } catch (e) {
      _handleSupabaseError(e, 'upsert remote vault item (${item.id})');
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
      _handleSupabaseError(e, 'bulk upsert remote vault items');
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
      _handleSupabaseError(e, 'delete remote vault item ($id)');
    }
  }

  @override
  Future<void> wipeRemoteVault() async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000');
    } catch (e) {
      _handleSupabaseError(e, 'wipe remote vault');
    }
  }
}

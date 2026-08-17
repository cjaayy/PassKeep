import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/backup_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/supabase_auth_providers.dart';
import '../../../auth/presentation/widgets/supabase_auth_sheet.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';

/// Settings & Vault Management Screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.exportVaultDataToFile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encrypted backup exported successfully.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final count = await backupService.importVaultDataFromFilePicker();

      if (count != null && mounted) {
        await ref.read(vaultNotifierProvider.notifier).loadVaultItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported and restored $count items.'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _handleSync() async {
    final result = await ref.read(syncNotifierProvider.notifier).sync();
    if (mounted) {
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud sync complete. ${result.totalChanges} changes synced.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Sync failed.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openAuthSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupabaseAuthSheet(),
    );
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sign Out from Cloud?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your local encrypted vault will remain accessible on this device with your Master PIN, but cloud sync will be paused.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && mounted) {
      await ref.read(supabaseUserProvider.notifier).signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out from Supabase cloud.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final userState = ref.watch(supabaseUserProvider);
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Settings & Vault',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Section: Account & Cloud Sync
          _buildSectionHeader('Account & Cloud Sync'),
          _buildCard(
            children: [
              if (!userState.isAuthenticated) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_off_rounded, color: Color(0xFF38BDF8)),
                  ),
                  title: const Text(
                    'Local Vault (Offline)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Sign in to sync your vault to Supabase Cloud',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _openAuthSheet,
                    child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_circle_rounded, color: Color(0xFF10B981)),
                  ),
                  title: Text(
                    userState.email ?? 'Cloud Account',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Connected to Supabase Cloud',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Sign Out',
                    onPressed: _confirmSignOut,
                  ),
                ),
                const Divider(color: Color(0xFF334155), height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Cloud Synchronization', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    syncState.lastSyncedAt != null
                        ? 'Last synced: ${syncState.lastSyncedAt!.toLocal().toString().split('.').first}'
                        : 'Not synchronized yet',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF10B981),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF10B981), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: syncState.isSyncing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sync', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: syncState.isSyncing ? null : _handleSync,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Section: Vault Data Transfer
          _buildSectionHeader('Data Transfer & Backups'),
          _buildCard(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_upload_outlined, color: Color(0xFF10B981)),
                ),
                title: const Text('Export Vault Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Export an AES-256 encrypted .passkeep archive', style: TextStyle(color: Colors.white60, fontSize: 12)),
                trailing: _isExporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                    : const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                onTap: _isExporting ? null : _handleExport,
              ),
              const Divider(color: Color(0xFF334155), height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_download_outlined, color: Color(0xFF38BDF8)),
                ),
                title: const Text('Import Vault Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Restore passwords from a .passkeep backup file', style: TextStyle(color: Colors.white60, fontSize: 12)),
                trailing: _isImporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
                    : const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                onTap: _isImporting ? null : _handleImport,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section: Security & Access
          _buildSectionHeader('Security & Access'),
          _buildCard(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: Color(0xFFA855F7)),
                ),
                title: const Text('Biometric Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  authState.isBiometricsAvailable ? 'Supported on this device' : 'Not available or not configured',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: Icon(
                  authState.isBiometricsAvailable ? Icons.check_circle_rounded : Icons.cancel_outlined,
                  color: authState.isBiometricsAvailable ? const Color(0xFF10B981) : Colors.white38,
                ),
              ),
              const Divider(color: Color(0xFF334155), height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B)),
                ),
                title: const Text('Auto-Lock on Background', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Locks vault after 30 seconds in background', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              const Divider(color: Color(0xFF334155), height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFEF4444)),
                ),
                title: const Text('Lock Application Now', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                subtitle: const Text('Clears in-memory keys and returns to lock screen', style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  ref.read(authNotifierProvider.notifier).lockVault();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section: About & Security Specs
          _buildSectionHeader('About PassKeep'),
          _buildCard(
            children: const [
              ListTile(
                leading: Icon(Icons.shield_outlined, color: Color(0xFF10B981)),
                title: Text('Architecture', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Zero-Knowledge Client-Side Encryption', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              Divider(color: Color(0xFF334155), height: 1),
              ListTile(
                leading: Icon(Icons.enhanced_encryption_rounded, color: Color(0xFF38BDF8)),
                title: Text('Encryption Standard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('AES-256-CBC with PKCS7 & PBKDF2 (100k rounds)', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              Divider(color: Color(0xFF334155), height: 1),
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: Colors.white60),
                title: Text('App Version', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: Text('1.0.0+1', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF10B981),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

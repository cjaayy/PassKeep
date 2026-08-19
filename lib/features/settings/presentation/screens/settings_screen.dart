import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/supabase_auth_providers.dart';
import '../../../auth/presentation/widgets/supabase_auth_sheet.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/change_master_pin_sheet.dart';

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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Encrypted backup exported successfully.'),
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: AppTheme.darkDestructive,
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported and restored $count items.'),
              backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
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
            backgroundColor: AppTheme.darkDestructive,
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud sync complete. ${result.totalChanges} changes synced.'),
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Sync failed.'),
            backgroundColor: AppTheme.darkDestructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleWipeRemoteAndResync() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const WipeRemoteConfirmationDialog(),
    );

    if (confirm == true && mounted) {
      final result = await ref.read(syncNotifierProvider.notifier).wipeRemoteAndResync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSuccess
                  ? 'Remote database wiped. Pushed ${result.pushedCount} local items.'
                  : result.errorMessage ?? 'Wipe & sync failed.',
            ),
            backgroundColor: result.isSuccess
                ? (isDark ? AppTheme.darkSurface : AppTheme.lightPrimary)
                : AppTheme.darkDestructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        title: Text(
          'Sign Out from Cloud?',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Your local encrypted vault will remain accessible on this device with your Master PIN, but cloud sync will be paused.',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
              foregroundColor: AppTheme.darkDestructive,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && mounted) {
      await ref.read(supabaseUserProvider.notifier).signOut();
      ref.read(isVaultSessionUnlockedProvider.notifier).state = false;
      ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _connectCloudAccount() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupabaseAuthSheet(initialTabIndex: 0),
    );

    final userState = ref.read(supabaseUserProvider);
    if (userState.isAuthenticated) {
      ref.read(authNotifierProvider.notifier).setOfflineOnlyMode(false);
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.cloud_done_rounded,
                  color: isDark ? AppTheme.darkPrimary : AppTheme.lightOnPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Connected cloud account: ${userState.email}'),
                ),
              ],
            ),
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleChangeMasterPin() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangeMasterPinSheet(),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Master PIN updated successfully!'),
            ],
          ),
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final userState = ref.watch(supabaseUserProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final settingsState = ref.watch(settingsNotifierProvider);

    final isCloudSyncEnabled = !authState.isOfflineOnlyMode && userState.isAuthenticated;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedTextColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final badgeBgColor = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings & Vault',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: primaryTextColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Section: Appearance & Theme
          _buildSectionHeader('Appearance & Theme'),
          _buildCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            settingsState.themeMode == ThemeMode.light
                                ? Icons.light_mode_rounded
                                : settingsState.themeMode == ThemeMode.dark
                                    ? Icons.dark_mode_rounded
                                    : Icons.brightness_auto_rounded,
                            color: primaryTextColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme Mode',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              settingsState.themeMode == ThemeMode.system
                                  ? 'System Default'
                                  : settingsState.themeMode == ThemeMode.light
                                      ? 'Light Mode'
                                      : 'Dark Mode',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Theme Switcher Segmented Buttons
                    Row(
                      children: [
                        _buildThemeOption(
                          label: 'System',
                          icon: Icons.brightness_auto_rounded,
                          isSelected: settingsState.themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(settingsNotifierProvider.notifier)
                              .setThemeMode(ThemeMode.system),
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          label: 'Light',
                          icon: Icons.light_mode_rounded,
                          isSelected: settingsState.themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(settingsNotifierProvider.notifier)
                              .setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          label: 'Dark',
                          icon: Icons.dark_mode_rounded,
                          isSelected: settingsState.themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(settingsNotifierProvider.notifier)
                              .setThemeMode(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section: Account & Cloud Sync
          _buildSectionHeader('Account & Cloud Sync'),
          if (isCloudSyncEnabled) ...[
            _buildCard(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_circle_rounded, color: primaryTextColor),
                  ),
                  title: Text(
                    userState.email ?? 'Cloud Account',
                    style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Connected to Supabase Cloud',
                    style: TextStyle(color: mutedTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppTheme.darkDestructive, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: _confirmSignOut,
                  ),
                ),
                Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.sync_lock_rounded, color: primaryTextColor),
                  ),
                  title: Text(
                    'Auto-Sync Passwords',
                    style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Automatically upload new or updated items when online',
                    style: TextStyle(color: mutedTextColor, fontSize: 12),
                  ),
                  value: settingsState.autoSyncEnabled,
                  activeThumbColor: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
                  activeTrackColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                  inactiveThumbColor: mutedTextColor,
                  inactiveTrackColor: isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill,
                  onChanged: (bool value) {
                    ref.read(settingsNotifierProvider.notifier).setAutoSyncEnabled(value);
                  },
                ),
                Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cloud_sync_rounded, color: primaryTextColor),
                  ),
                  title: Text(
                    'Cloud Synchronization',
                    style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    syncState.lastSyncedAt != null
                        ? 'Last synced: ${syncState.lastSyncedAt!.toLocal().toString().split('.').first}'
                        : 'Not synchronized yet',
                    style: TextStyle(color: mutedTextColor, fontSize: 12),
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                      foregroundColor: primaryTextColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: syncState.isSyncing
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryTextColor,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sync', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: syncState.isSyncing ? null : _handleSync,
                  ),
                ),
                Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkDestructive.withValues(alpha: 0.15)
                          : AppTheme.lightDestructive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: AppTheme.darkDestructive),
                  ),
                  title: Text(
                    'Wipe Remote & Re-sync',
                    style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Clear remote cloud vault and upload current local entries',
                    style: TextStyle(color: mutedTextColor, fontSize: 12),
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                      foregroundColor: AppTheme.darkDestructive,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Wipe & Push', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: syncState.isSyncing ? null : _handleWipeRemoteAndResync,
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildCard(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cloud_off_rounded, color: mutedTextColor),
                  ),
                  title: Text(
                    'Cloud Sync Disabled',
                    style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Operating in Offline Mode. Multi-device sync is disabled.',
                    style: TextStyle(color: mutedTextColor, fontSize: 12),
                  ),
                ),
                Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
                        foregroundColor: isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: const Text(
                        'Sign In / Connect Cloud Account',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                      onPressed: _connectCloudAccount,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Section: Vault Data Transfer
          _buildSectionHeader('Data Transfer & Backups'),
          _buildCard(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.file_upload_outlined, color: primaryTextColor),
                ),
                title: Text('Export Vault Data', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Export an AES-256 encrypted .passkeep archive', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                trailing: _isExporting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryTextColor,
                        ),
                      )
                    : Icon(Icons.chevron_right_rounded, color: mutedTextColor),
                onTap: _isExporting ? null : _handleExport,
              ),
              Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.file_download_outlined, color: primaryTextColor),
                ),
                title: Text('Import Vault Data', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Restore passwords from a .passkeep backup file', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                trailing: _isImporting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryTextColor,
                        ),
                      )
                    : Icon(Icons.chevron_right_rounded, color: mutedTextColor),
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
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.pin_outlined, color: primaryTextColor),
                ),
                title: Text('Change Master PIN', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Update your primary vault unlock PIN', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                trailing: Icon(Icons.chevron_right_rounded, color: mutedTextColor),
                onTap: _handleChangeMasterPin,
              ),
              Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fingerprint_rounded, color: primaryTextColor),
                ),
                title: Text('Biometric Unlock', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  authState.isBiometricsAvailable ? 'Supported on this device' : 'Not available or not configured',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                trailing: Icon(
                  authState.isBiometricsAvailable ? Icons.check_circle_rounded : Icons.cancel_outlined,
                  color: authState.isBiometricsAvailable ? primaryTextColor : mutedTextColor,
                ),
              ),
              Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.timer_outlined, color: primaryTextColor),
                ),
                title: Text('Auto-Lock on Background', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Locks vault after 30 seconds in background', style: TextStyle(color: mutedTextColor, fontSize: 12)),
              ),
              Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkDestructive.withValues(alpha: 0.15)
                        : AppTheme.lightDestructive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_rounded, color: AppTheme.darkDestructive),
                ),
                title: const Text('Lock Application Now', style: TextStyle(color: AppTheme.darkDestructive, fontWeight: FontWeight.bold)),
                subtitle: Text('Clears in-memory keys and returns to lock screen', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                onTap: () {
                  ref.read(authNotifierProvider.notifier).lockVault();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section: About PassKeep
          _buildSectionHeader('About PassKeep'),
          _buildCard(
            children: [
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: primaryTextColor),
                title: Text('App Version', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                trailing: Text('1.0.0+1', style: TextStyle(color: mutedTextColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final selectedFg = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;
    final unselectedBg = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final unselectedFg = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? selectedFg : unselectedFg,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? selectedFg : unselectedFg,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: mutedColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
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

/// Safety confirmation dialog with a mandatory 10-second countdown timer.
class WipeRemoteConfirmationDialog extends StatefulWidget {
  final int initialCountdownSeconds;

  const WipeRemoteConfirmationDialog({
    super.key,
    this.initialCountdownSeconds = 10,
  });

  @override
  State<WipeRemoteConfirmationDialog> createState() =>
      _WipeRemoteConfirmationDialogState();
}

class _WipeRemoteConfirmationDialogState
    extends State<WipeRemoteConfirmationDialog> {
  Timer? _timer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialCountdownSeconds;
    if (_secondsRemaining > 0) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _secondsRemaining = 0;
          });
        }
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final isCountdownActive = _secondsRemaining > 0;

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.darkDestructive, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Wipe Remote Vault?',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action will permanently delete ALL remote vault items stored in your Supabase cloud database, and re-upload your current local decrypted items as a fresh baseline.',
            style: TextStyle(
              color: textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkDestructive.withValues(alpha: 0.1)
                  : AppTheme.lightDestructive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: isCountdownActive ? AppTheme.darkDestructive : textPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCountdownActive
                        ? 'Safety delay active: $_secondsRemaining second${_secondsRemaining == 1 ? '' : 's'}'
                        : 'Safety delay elapsed. Ready to confirm.',
                    style: TextStyle(
                      color: isCountdownActive ? AppTheme.darkDestructive : textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isCountdownActive
                ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7))
                : AppTheme.darkDestructive,
            foregroundColor: isCountdownActive
                ? textMuted
                : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: isCountdownActive
              ? null
              : () => Navigator.pop(context, true),
          child: Text(
            isCountdownActive
                ? 'Confirm Wipe (${_secondsRemaining}s)'
                : 'Confirm Wipe & Re-sync',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

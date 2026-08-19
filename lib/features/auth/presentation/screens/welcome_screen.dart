import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';
import '../providers/supabase_auth_providers.dart';
import '../widgets/supabase_auth_sheet.dart';
import 'setup_master_pin_screen.dart';
import 'verify_master_pin_screen.dart';

/// Initial Welcome & Onboarding Screen for PassKeep
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  void _navigateToPinSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SetupMasterPinScreen()),
    );
  }

  Future<void> _handleCloudAuth(BuildContext context, WidgetRef ref, {required int initialTabIndex}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupabaseAuthSheet(initialTabIndex: initialTabIndex),
    );

    if (result == true && context.mounted) {
      final user = ref.read(supabaseUserProvider).user;
      final remoteSalt = user?.userMetadata?['master_pin_salt'] as String?;

      if (remoteSalt != null && remoteSalt.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VerifyMasterPinScreen()),
        );
      } else {
        _navigateToPinSetup(context);
      }
    }
  }

  void _handleContinueOffline(BuildContext context, WidgetRef ref) {
    ref.read(authNotifierProvider.notifier).setOfflineOnlyMode(true);
    _navigateToPinSetup(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),

                // Brand Logo & Shield (Borderless)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 48,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // App Name & Tagline
                Text(
                  'PassKeep',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zero-Knowledge Password Manager',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure, client-side encrypted credentials with optional cloud sync and full offline autonomy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Value Proposition Cards (Borderless)
                _buildFeatureRow(
                  context: context,
                  icon: Icons.lock_outline_rounded,
                  title: 'Client-Side AES-256 Encryption',
                  description: 'Keys derived via PBKDF2 (100k rounds). Only you hold the decryption key.',
                ),
                const SizedBox(height: 10),
                _buildFeatureRow(
                  context: context,
                  icon: Icons.offline_bolt_outlined,
                  title: 'Offline-First & Local-First',
                  description: 'Works 100% offline. Your passwords always reside on your device first.',
                ),
                const SizedBox(height: 10),
                _buildFeatureRow(
                  context: context,
                  icon: Icons.cloud_sync_outlined,
                  title: 'Optional Cloud Synchronization',
                  description: 'Sync your encrypted vault across devices with Supabase.',
                ),
                const SizedBox(height: 24),

                // Action Buttons (Monochromatic)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryAction,
                      foregroundColor: onPrimaryAction,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _handleCloudAuth(context, ref, initialTabIndex: 1),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: inputFill,
                      foregroundColor: textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.login_rounded, size: 18, color: textPrimary),
                    label: const Text(
                      'Sign In to Existing Account',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _handleCloudAuth(context, ref, initialTabIndex: 0),
                  ),
                ),
                const SizedBox(height: 8),

                // Continue Offline Button
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: textMuted,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text(
                    'Continue Offline (Local Storage Only)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () => _handleContinueOffline(context, ref),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

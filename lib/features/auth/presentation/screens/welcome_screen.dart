import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../widgets/supabase_auth_sheet.dart';
import 'setup_master_pin_screen.dart';

/// Initial Welcome & Onboarding Screen for PassKeep
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  void _navigateToPinSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SetupMasterPinScreen()),
    );
  }

  Future<void> _handleCloudAuth(BuildContext context, {required int initialTabIndex}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupabaseAuthSheet(initialTabIndex: initialTabIndex),
    );

    if (result == true && context.mounted) {
      _navigateToPinSetup(context);
    }
  }

  void _handleContinueOffline(BuildContext context, WidgetRef ref) {
    ref.read(authNotifierProvider.notifier).setOfflineOnlyMode(true);
    _navigateToPinSetup(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),

                // Brand Logo & Shield
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 48,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 12),

                // App Name & Tagline
                const Text(
                  'PassKeep',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Zero-Knowledge Password Manager',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Secure, client-side encrypted credentials with optional cloud sync and full offline autonomy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),

                // Value Proposition Cards
                _buildFeatureRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Client-Side AES-256 Encryption',
                  description: 'Keys derived via PBKDF2 (100k rounds). Only you hold the decryption key.',
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  icon: Icons.offline_bolt_outlined,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Offline-First & Local-First',
                  description: 'Works 100% offline. Your passwords always reside on your device first.',
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  icon: Icons.cloud_sync_outlined,
                  iconColor: const Color(0xFFA855F7),
                  title: 'Optional Cloud Synchronization',
                  description: 'Sync your encrypted vault across devices with Supabase.',
                ),
                const SizedBox(height: 20),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
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
                    onPressed: () => _handleCloudAuth(context, initialTabIndex: 1),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 18, color: Color(0xFF38BDF8)),
                    label: const Text(
                      'Sign In to Existing Account',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _handleCloudAuth(context, initialTabIndex: 0),
                  ),
                ),
                const SizedBox(height: 6),

                // Continue Offline Button
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
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
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
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

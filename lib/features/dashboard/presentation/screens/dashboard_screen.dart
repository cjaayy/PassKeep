import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/supabase_auth_providers.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../vault/data/models/vault_item.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../../vault/presentation/screens/add_edit_vault_screen.dart';
import '../../../vault/presentation/widgets/password_generator_sheet.dart';

/// Dashboard overview screen serving as the initial tab (Tab 0) in PassKeep.
class DashboardScreen extends ConsumerWidget {
  final VoidCallback? onNavigateToPasswords;
  final VoidCallback? onNavigateToCards;

  const DashboardScreen({
    super.key,
    this.onNavigateToPasswords,
    this.onNavigateToCards,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final userState = ref.watch(supabaseUserProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;

    final passwordCount = vaultState.allItems.where((i) => !i.isCard).length;
    final cardCount = vaultState.allItems.where((i) => i.isCard).length;
    final totalCount = vaultState.allItems.length;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(vaultNotifierProvider.notifier).loadVaultItems();
            final isCloudSyncEnabled = !authState.isOfflineOnlyMode && userState.isAuthenticated;
            if (isCloudSyncEnabled) {
              await ref.read(syncNotifierProvider.notifier).sync();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vault Overview Card
                Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VAULT OVERVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            authState.isOfflineOnlyMode ? 'OFFLINE' : (userState.isAuthenticated ? 'SYNCED' : 'LOCAL'),
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Encrypted Items',
                      style: TextStyle(
                        fontSize: 13,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(color: inputFill, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onNavigateToPasswords,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.vpn_key_rounded, size: 20, color: textPrimary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$passwordCount',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Passwords',
                                          style: TextStyle(fontSize: 11, color: textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onNavigateToCards,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.credit_card_rounded, size: 20, color: textPrimary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$cardCount',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Cards',
                                          style: TextStyle(fontSize: 11, color: textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions Header
              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Action Tiles
              _buildActionTile(
                context: context,
                icon: Icons.vpn_key_rounded,
                title: 'New Password',
                subtitle: 'Store a new password, login, or QR credential',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditVaultScreen(vaultType: VaultType.password),
                    ),
                  );
                },
                surfaceColor: surfaceColor,
                inputFill: inputFill,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
              const SizedBox(height: 10),

              _buildActionTile(
                context: context,
                icon: Icons.credit_card_rounded,
                title: 'New Payment Card',
                subtitle: 'Add a credit/debit card with zero-knowledge encryption',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditVaultScreen(vaultType: VaultType.card),
                    ),
                  );
                },
                surfaceColor: surfaceColor,
                inputFill: inputFill,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
              const SizedBox(height: 10),

              _buildActionTile(
                context: context,
                icon: Icons.auto_awesome_rounded,
                title: 'Password Generator',
                subtitle: 'Generate strong, customizable passwords',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const PasswordGeneratorSheet(),
                  );
                },
                surfaceColor: surfaceColor,
                inputFill: inputFill,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color inputFill,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: textMuted),
          ],
        ),
      ),
    );
  }
}

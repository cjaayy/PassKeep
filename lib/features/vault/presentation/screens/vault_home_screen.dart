import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/supabase_auth_providers.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../data/models/vault_item.dart';
import '../providers/vault_providers.dart';
import '../providers/vault_state.dart';
import '../widgets/vault_detail_sheet.dart';
import '../widgets/vault_group_card.dart';
import '../widgets/vault_item_card.dart';
import '../widgets/verify_master_pin_sheet.dart';
import 'add_edit_vault_screen.dart';

/// Main screen of PassKeep with tabbed navigation:
/// - Tab 0: Passwords View
/// - Tab 1: Cards View
/// - Tab 2: Settings View
/// With dedicated Add triggers from the bottom navigation bar.
class VaultHomeScreen extends ConsumerStatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  ConsumerState<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends ConsumerState<VaultHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passwordSearchController = TextEditingController();
  final TextEditingController _cardSearchController = TextEditingController();

  late AnimationController _syncAnimationController;
  int _selectedTabIndex = 0; // 0: Passwords, 1: Cards, 2: Settings

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Initial load of vault items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vaultNotifierProvider.notifier).loadVaultItems();
    });
  }

  @override
  void dispose() {
    _passwordSearchController.dispose();
    _cardSearchController.dispose();
    _syncAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    _syncAnimationController.repeat();
    final result = await ref.read(syncNotifierProvider.notifier).sync();
    _syncAnimationController.stop();
    _syncAnimationController.reset();

    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault synced. ${result.totalChanges} changes updated.'),
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
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

  Future<void> _openDetailSheet(VaultItem item) async {
    final isSessionUnlocked = ref.read(isVaultSessionUnlockedProvider);

    if (!isSessionUnlocked) {
      final unlocked = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const VerifyMasterPinSheet(),
      );

      if (unlocked != true) {
        return;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VaultDetailSheet(item: item),
    );
  }

  void _showAddTypeModalSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Add to Vault',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the type of entry you want to create',
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),

              // Option 1: Password / Account
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditVaultScreen(vaultType: VaultType.password),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.vpn_key_rounded, size: 22, color: textPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password / Account',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Logins, apps, websites, credentials & QR codes',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Payment Card
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditVaultScreen(vaultType: VaultType.card),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.credit_card_rounded, size: 22, color: textPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Card',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Debit & credit cards, CVV, expiry & PIN',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final userState = ref.watch(supabaseUserProvider);

    final isCloudSyncEnabled = !authState.isOfflineOnlyMode && userState.isAuthenticated;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final scaffoldBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _selectedTabIndex == 4
          ? null // SettingsScreen provides its own AppBar
          : AppBar(
              backgroundColor: scaffoldBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  Icon(
                    _selectedTabIndex == 3
                        ? Icons.credit_card_rounded
                        : (_selectedTabIndex == 1 ? Icons.vpn_key_rounded : Icons.shield_rounded),
                    color: textPrimary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedTabIndex == 3
                        ? 'Payment Cards'
                        : (_selectedTabIndex == 1 ? 'Passwords' : 'PassKeep'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                // Refresh Vault Action
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: textMuted),
                  tooltip: 'Refresh Vault',
                  onPressed: () async {
                    await ref.read(vaultNotifierProvider.notifier).loadVaultItems();
                    if (isCloudSyncEnabled) {
                      _handleSync();
                    }
                  },
                ),
                // Sync Button
                if (isCloudSyncEnabled)
                  RotationTransition(
                    turns: _syncAnimationController,
                    child: IconButton(
                      icon: Icon(
                        Icons.sync_rounded,
                        color: textPrimary,
                      ),
                      tooltip: 'Sync with Cloud',
                      onPressed: syncState.isSyncing ? null : _handleSync,
                    ),
                  ),
                // Lock Vault Button
                IconButton(
                  icon: Icon(Icons.lock_outline_rounded, color: textMuted),
                  tooltip: 'Lock Vault',
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).lockVault();
                  },
                ),
                const SizedBox(width: 6),
              ],
            ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          // Tab 0: PassKeep Dashboard
          DashboardScreen(
            onNavigateToPasswords: () => setState(() => _selectedTabIndex = 1),
            onNavigateToCards: () => setState(() => _selectedTabIndex = 3),
          ),
          // Tab 1: Passwords View (Search + Category Filter Chips + Login Items)
          _buildPasswordsView(vaultState),
          // Tab 2: Placeholder for Add action tab
          const SizedBox.shrink(),
          // Tab 3: Cards View (Search + Pure Payment Cards List, NO Category Chips)
          _buildCardsView(vaultState),
          // Tab 4: Settings View
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: scaffoldBg,
          elevation: 0,
          indicatorColor: inputFill,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              );
            }
            return TextStyle(
              color: textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(
                color: textPrimary,
                size: 24,
              );
            }
            return IconThemeData(color: textMuted, size: 24);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (index) {
            if (index == 2) {
              _showAddTypeModalSheet();
            } else {
              setState(() => _selectedTabIndex = index);
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded),
              label: 'PassKeep',
            ),
            const NavigationDestination(
              icon: Icon(Icons.vpn_key_outlined),
              selectedIcon: Icon(Icons.vpn_key_rounded),
              label: 'Passwords',
            ),
            NavigationDestination(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryAction,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: onPrimaryAction, size: 18),
              ),
              selectedIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryAction,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: onPrimaryAction, size: 18),
              ),
              label: 'Add',
            ),
            const NavigationDestination(
              icon: Icon(Icons.credit_card_outlined),
              selectedIcon: Icon(Icons.credit_card_rounded),
              label: 'Cards',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PASSWORDS VIEW (Tab 0: Passwords, Search & Categories)
  // ----------------------------------------------------
  Widget _buildPasswordsView(VaultState vaultState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    // Strictly isolate only login/password items
    final passwordItems = vaultState.filteredPasswordItems;
    final passwordGroups = vaultState.groupedPasswordItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Bar (Borderless)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _passwordSearchController,
            style: TextStyle(color: textPrimary),
            onChanged: (query) {
              ref.read(vaultNotifierProvider.notifier).setSearchQuery(query);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: inputFill,
              hintText: 'Search passwords, usernames, categories...',
              hintStyle: TextStyle(color: textMuted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: textMuted),
              suffixIcon: _passwordSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: textMuted, size: 18),
                      onPressed: () {
                        _passwordSearchController.clear();
                        ref.read(vaultNotifierProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Categories Section Header
        _buildSectionHeader('Categories'),

        // Category Chips Bar (Passwords Only, Borderless)
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vaultState.availableCategories.length,
            itemBuilder: (context, index) {
              final category = vaultState.availableCategories[index];
              final isSelected =
                  vaultState.selectedCategory.toLowerCase() == category.toLowerCase();

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(category.toUpperCase()),
                  selected: isSelected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: isSelected ? onPrimaryAction : textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                  backgroundColor: inputFill,
                  selectedColor: primaryAction,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (_) {
                    ref.read(vaultNotifierProvider.notifier).setCategoryFilter(category);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Vault Passwords Section Header
        if (passwordItems.isNotEmpty)
          _buildSectionHeader(
            passwordGroups.length == passwordItems.length
                ? 'Vault Passwords (${passwordItems.length})'
                : 'Vault Passwords (${passwordGroups.length} Platforms • ${passwordItems.length} Logins)',
          ),

        // Password Items List
        Expanded(
          child: _buildPasswordContent(vaultState, passwordItems, passwordGroups),
        ),
      ],
    );
  }

  Widget _buildPasswordContent(
    VaultState state,
    List<VaultItem> passwordItems,
    List<VaultItemGroup> passwordGroups,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    if (state.status == VaultStatus.loading && state.allItems.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: primaryAction),
      );
    }

    if (passwordItems.isEmpty) {
      final isFilteredByCategory = state.selectedCategory.toLowerCase() != 'all';
      final isSearching = state.searchQuery.trim().isNotEmpty;

      String emptyTitle;
      String emptySubtitle;

      if (isSearching) {
        emptyTitle = 'No Matching Passwords';
        emptySubtitle = 'No accounts match your search query.';
      } else if (isFilteredByCategory) {
        emptyTitle = '${state.selectedCategory} is Empty';
        emptySubtitle = 'No passwords saved in this category yet.';
      } else {
        emptyTitle = 'No Passwords Saved';
        emptySubtitle = 'Your encrypted vault has no password items. Tap "+ Add" below to store one.';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFilteredByCategory ? Icons.folder_open_rounded : Icons.vpn_key_outlined,
                size: 56,
                color: textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (!isSearching && !isFilteredByCategory) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAction,
                    foregroundColor: onPrimaryAction,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'ADD FIRST PASSWORD',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditVaultScreen(vaultType: VaultType.password),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: primaryAction,
      backgroundColor: inputFill,
      onRefresh: () => ref.read(vaultNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24, top: 4),
        itemCount: passwordGroups.length,
        itemBuilder: (context, index) {
          final group = passwordGroups[index];

          if (group.isMultiAccount) {
            return VaultGroupCard(
              group: group,
              onItemTap: _openDetailSheet,
            );
          } else {
            final singleItem = group.items.first;
            return VaultItemCard(
              item: singleItem,
              onTap: () => _openDetailSheet(singleItem),
            );
          }
        },
      ),
    );
  }

  // ----------------------------------------------------
  // CARDS VIEW (Tab 1: Payment Cards Only, NO Category Bar)
  // ----------------------------------------------------
  Widget _buildCardsView(VaultState vaultState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;

    // Strictly isolate payment card items (ignores selectedCategory)
    final cardItems = vaultState.filteredCardItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Search Input Bar (Borderless)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _cardSearchController,
            style: TextStyle(color: textPrimary),
            onChanged: (query) {
              ref.read(vaultNotifierProvider.notifier).setSearchQuery(query);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: inputFill,
              hintText: 'Search cards, banks, cardholder...',
              hintStyle: TextStyle(color: textMuted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: textMuted),
              suffixIcon: _cardSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: textMuted, size: 18),
                      onPressed: () {
                        _cardSearchController.clear();
                        ref.read(vaultNotifierProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Section Header (No Category Chips in Cards view)
        if (cardItems.isNotEmpty) ...[
          _buildSectionHeader('Payment Cards (${cardItems.length})'),
        ],
        Expanded(
          child: _buildCardContent(vaultState, cardItems),
        ),
      ],
    );
  }

  Widget _buildCardContent(VaultState state, List<VaultItem> cardItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    if (state.status == VaultStatus.loading && state.allItems.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: primaryAction),
      );
    }

    if (cardItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  size: 56,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Payment Cards Saved',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Store your credit and debit cards with zero-knowledge encryption, bank favicons, and card network logos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAction,
                  foregroundColor: onPrimaryAction,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'ADD PAYMENT CARD',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditVaultScreen(vaultType: VaultType.card),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: primaryAction,
      backgroundColor: inputFill,
      onRefresh: () => ref.read(vaultNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24, top: 4),
        itemCount: cardItems.length,
        itemBuilder: (context, index) {
          final item = cardItems[index];
          return VaultItemCard(
            item: item,
            onTap: () => _openDetailSheet(item),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

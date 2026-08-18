import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/supabase_auth_providers.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../data/models/vault_item.dart';
import '../providers/vault_providers.dart';
import '../providers/vault_state.dart';
import '../widgets/vault_detail_sheet.dart';
import '../widgets/vault_group_card.dart';
import '../widgets/vault_item_card.dart';
import 'add_edit_vault_screen.dart';

/// Main Dashboard Screen for PassKeep with Context-Aware Bottom Navigation Bar
class VaultHomeScreen extends ConsumerStatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  ConsumerState<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends ConsumerState<VaultHomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0: Passwords, 1: Cards, 2: Settings
  final TextEditingController _passwordSearchController = TextEditingController();
  final TextEditingController _cardSearchController = TextEditingController();
  late AnimationController _syncAnimationController;

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Initial load
    Future.microtask(() => ref.read(vaultNotifierProvider.notifier).loadVaultItems());
  }

  @override
  void dispose() {
    _passwordSearchController.dispose();
    _cardSearchController.dispose();
    _syncAnimationController.dispose();
    super.dispose();
  }

  void _openDetailSheet(VaultItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VaultDetailSheet(item: item),
    );
  }

  Future<void> _handleSync() async {
    _syncAnimationController.repeat();
    final result = await ref.read(syncNotifierProvider.notifier).sync();
    _syncAnimationController.stop();
    _syncAnimationController.reset();

    if (mounted) {
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync completed. ${result.totalChanges} changes synced.'),
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

  void _onAddTapped() {
    // Context-aware Add Trigger:
    // If on Cards tab -> open AddEditVaultScreen with 'card' mode
    // Otherwise -> open AddEditVaultScreen with 'login' mode
    final initialType = _selectedTabIndex == 1 ? 'card' : 'login';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditVaultScreen(initialItemType: initialType),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final userState = ref.watch(supabaseUserProvider);
    final syncState = ref.watch(syncNotifierProvider);

    final isCloudSyncEnabled = !authState.isOfflineOnlyMode && userState.isAuthenticated;

    // Calculate active navigation bar index
    int navIndex;
    if (_selectedTabIndex == 0) {
      navIndex = 0;
    } else if (_selectedTabIndex == 1) {
      navIndex = 2;
    } else {
      navIndex = 3;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _selectedTabIndex == 2
          ? null // SettingsScreen provides its own AppBar
          : AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              title: Row(
                children: [
                  Icon(
                    _selectedTabIndex == 1 ? Icons.credit_card_rounded : Icons.shield_rounded,
                    color: _selectedTabIndex == 1 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedTabIndex == 1 ? 'Payment Cards' : 'PassKeep',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                // Sync Button
                if (isCloudSyncEnabled)
                  RotationTransition(
                    turns: _syncAnimationController,
                    child: IconButton(
                      icon: Icon(
                        Icons.sync_rounded,
                        color: syncState.isSyncing ? const Color(0xFF10B981) : Colors.white70,
                      ),
                      tooltip: 'Sync with Cloud',
                      onPressed: syncState.isSyncing ? null : _handleSync,
                    ),
                  ),
                // Lock Vault Button
                IconButton(
                  icon: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
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
          // Tab 0: Passwords View (Search + Category Filter Chips + Login Items)
          _buildPasswordsView(vaultState),
          // Tab 1: Cards View (Search + Pure Payment Cards List, NO Category Chips)
          _buildCardsView(vaultState),
          // Tab 2: Settings View
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(
            top: BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: const Color(0xFF0F172A),
            indicatorColor: _selectedTabIndex == 1
                ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                : const Color(0xFF10B981).withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  color: _selectedTabIndex == 1 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
              }
              return const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(
                  color: _selectedTabIndex == 1 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  size: 24,
                );
              }
              return const IconThemeData(color: Color(0xFF64748B), size: 24);
            }),
          ),
          child: NavigationBar(
            selectedIndex: navIndex,
            onDestinationSelected: (index) {
              if (index == 0) {
                setState(() => _selectedTabIndex = 0);
              } else if (index == 1) {
                _onAddTapped();
              } else if (index == 2) {
                setState(() => _selectedTabIndex = 1);
              } else if (index == 3) {
                setState(() => _selectedTabIndex = 2);
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.vpn_key_outlined),
                selectedIcon: Icon(Icons.vpn_key_rounded),
                label: 'Passwords',
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _selectedTabIndex == 1 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _selectedTabIndex == 1 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
      ),
    );
  }

  // ----------------------------------------------------
  // PASSWORDS VIEW (Tab 0: Passwords, Search & Categories)
  // ----------------------------------------------------
  Widget _buildPasswordsView(VaultState vaultState) {
    // Filter only login/password items
    final passwordItems = vaultState.filteredItems.where((i) => !i.isCard).toList();
    final passwordGroups = vaultState.groupedItems
        .where((g) => g.items.any((i) => !i.isCard))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _passwordSearchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (query) {
              ref.read(vaultNotifierProvider.notifier).setSearchQuery(query);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E293B),
              hintText: 'Search passwords, usernames, categories...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF10B981)),
              suffixIcon: _passwordSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                      onPressed: () {
                        _passwordSearchController.clear();
                        ref.read(vaultNotifierProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
            ),
          ),
        ),

        // Categories Section Header
        _buildSectionHeader('Categories'),

        // Category Chips Bar (Passwords Only)
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
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  selectedColor: const Color(0xFF10B981),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    if (state.status == VaultStatus.loading && state.allItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
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
                size: 64,
                color: const Color(0xFF334155).withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Password', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditVaultScreen(initialItemType: 'login'),
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
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF1E293B),
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
    // Filter card items
    final cardItems = vaultState.filteredItems.where((i) => i.isCard).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Search Input Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _cardSearchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (query) {
              ref.read(vaultNotifierProvider.notifier).setSearchQuery(query);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E293B),
              hintText: 'Search cards, banks, cardholder...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6)),
              suffixIcon: _cardSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                      onPressed: () {
                        _cardSearchController.clear();
                        ref.read(vaultNotifierProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
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
    if (state.status == VaultStatus.loading && state.allItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
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
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  size: 56,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Payment Cards Saved',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Store your credit and debit cards with zero-knowledge encryption, bank favicons, and card network logos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      builder: (_) => const AddEditVaultScreen(initialItemType: 'card'),
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
      color: const Color(0xFF3B82F6),
      backgroundColor: const Color(0xFF1E293B),
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
}

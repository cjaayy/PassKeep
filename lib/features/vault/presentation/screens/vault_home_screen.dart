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
import '../widgets/vault_item_card.dart';
import 'add_edit_vault_screen.dart';

/// Main Dashboard Screen for PassKeep displaying encrypted credentials
class VaultHomeScreen extends ConsumerStatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  ConsumerState<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends ConsumerState<VaultHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = ['All', 'Work', 'Social', 'Finance', 'Personal'];
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
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final userState = ref.watch(supabaseUserProvider);
    final syncState = ref.watch(syncNotifierProvider);

    final isCloudSyncEnabled = !authState.isOfflineOnlyMode && userState.isAuthenticated;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text(
              'PassKeep',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          // Sync Button (Only visible if cloud account is connected and not in offline-only mode)
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
          // Settings & Backups Button
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings & Backups',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
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
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (query) {
                ref.read(vaultNotifierProvider.notifier).setSearchQuery(query);
              },
              decoration: InputDecoration(
                hintText: 'Search passwords, usernames, categories...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF10B981)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(vaultNotifierProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // Category Chips Bar
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = vaultState.selectedCategory.toLowerCase() == category.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    selectedColor: const Color(0xFF10B981),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (_) {
                      ref.read(vaultNotifierProvider.notifier).setCategoryFilter(category);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Vault Items List
          Expanded(
            child: _buildVaultContent(vaultState),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Password', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditVaultScreen()),
          );
        },
      ),
    );
  }

  Widget _buildVaultContent(VaultState state) {
    if (state.status == VaultStatus.loading && state.allItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    if (state.filteredItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: const Color(0xFF334155).withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Vault Items Found',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.searchQuery.isNotEmpty
                    ? 'No passwords match your search query.'
                    : 'Your encrypted vault is empty. Tap below to add your first password.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
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
        padding: const EdgeInsets.only(bottom: 90, top: 4),
        itemCount: state.filteredItems.length,
        itemBuilder: (context, index) {
          final item = state.filteredItems[index];
          return VaultItemCard(
            item: item,
            onTap: () => _openDetailSheet(item),
          );
        },
      ),
    );
  }
}

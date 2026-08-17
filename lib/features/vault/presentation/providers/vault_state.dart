import '../../data/models/vault_item.dart';

/// Status enum representing the state of Vault operations.
enum VaultStatus { initial, loading, success, error }

/// Immutable state representation for the Vault feature.
class VaultState {
  final VaultStatus status;
  final List<VaultItem> allItems;
  final List<VaultItem> filteredItems;
  final String selectedCategory;
  final String searchQuery;
  final String? errorMessage;

  const VaultState({
    required this.status,
    required this.allItems,
    required this.filteredItems,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.errorMessage,
  });

  /// Factory constructor for initial empty state.
  const VaultState.initial()
      : status = VaultStatus.initial,
        allItems = const [],
        filteredItems = const [],
        selectedCategory = 'All',
        searchQuery = '',
        errorMessage = null;

  /// Creates a copy of this state with specified overrides.
  VaultState copyWith({
    VaultStatus? status,
    List<VaultItem>? allItems,
    List<VaultItem>? filteredItems,
    String? selectedCategory,
    String? searchQuery,
    String? errorMessage,
  }) {
    return VaultState(
      status: status ?? this.status,
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'VaultState(status: $status, allCount: ${allItems.length}, filteredCount: ${filteredItems.length}, category: $selectedCategory, query: "$searchQuery", error: $errorMessage)';
  }
}

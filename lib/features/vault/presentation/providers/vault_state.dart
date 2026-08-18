import '../../data/models/vault_item.dart';

/// Status enum representing the state of Vault operations.
enum VaultStatus { initial, loading, success, error }

/// Represents a collection of [VaultItem] accounts grouped by service title
class VaultItemGroup {
  final String title;
  final List<VaultItem> items;

  const VaultItemGroup({
    required this.title,
    required this.items,
  });

  int get count => items.length;
  bool get isMultiAccount => items.length > 1;
  String get primaryCategory => items.isNotEmpty ? items.first.category : 'General';
}

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

  /// Returns [filteredItems] grouped by title (case-insensitive) for multi-account rendering
  List<VaultItemGroup> get groupedItems {
    final Map<String, List<VaultItem>> groupMap = {};
    for (final item in filteredItems) {
      final key = item.title.trim().toLowerCase();
      groupMap.putIfAbsent(key, () => []).add(item);
    }

    return groupMap.entries.map((entry) {
      final representativeTitle = entry.value.first.title.trim();
      return VaultItemGroup(
        title: representativeTitle,
        items: entry.value,
      );
    }).toList();
  }

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
    return 'VaultState(status: $status, allCount: ${allItems.length}, filteredCount: ${filteredItems.length}, groups: ${groupedItems.length}, category: $selectedCategory, query: "$searchQuery", error: $errorMessage)';
  }
}

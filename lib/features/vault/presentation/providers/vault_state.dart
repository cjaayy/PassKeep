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

  static const List<String> defaultPredefinedCategories = [
    'All',
    'General',
    'Personal',
    'Work',
    'School',
    'Social',
    'Finance',
    'Entertainment',
    'Shopping',
    'Developer / Tech',
    'Utilities',
  ];

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

  /// Returns all password/login items from [allItems] (excluding Payment Cards)
  List<VaultItem> get allPasswordItems =>
      allItems.where((item) => item.type != VaultType.card).toList();

  /// Returns all payment card items from [allItems]
  List<VaultItem> get allCardItems =>
      allItems.where((item) => item.type == VaultType.card).toList();

  /// Returns filtered password items based on [selectedCategory] and [searchQuery]
  List<VaultItem> get filteredPasswordItems {
    var result = allPasswordItems;

    // Filter by Category (Only applies to Passwords)
    if (selectedCategory.trim().isNotEmpty && selectedCategory.trim().toLowerCase() != 'all') {
      final normCategory = selectedCategory.trim().toLowerCase();
      result = result
          .where((item) => item.category.trim().toLowerCase() == normCategory)
          .toList();
    }

    // Filter by Search Query
    if (searchQuery.trim().isNotEmpty) {
      final normQuery = searchQuery.trim().toLowerCase();
      result = result
          .where((item) =>
              item.title.toLowerCase().contains(normQuery) ||
              item.category.toLowerCase().contains(normQuery) ||
              (item.accountNumber?.toLowerCase().contains(normQuery) ?? false))
          .toList();
    }

    return result;
  }

  /// Returns filtered payment card items (strictly ignores [selectedCategory], filtered ONLY by [searchQuery])
  List<VaultItem> get filteredCardItems {
    var result = allCardItems;

    // Filter by Search Query
    if (searchQuery.trim().isNotEmpty) {
      final normQuery = searchQuery.trim().toLowerCase();
      result = result
          .where((item) =>
              item.title.toLowerCase().contains(normQuery) ||
              (item.accountNumber?.toLowerCase().contains(normQuery) ?? false))
          .toList();
    }

    return result;
  }

  /// Returns predefined categories merged with any unique custom categories saved in [allPasswordItems]
  List<String> get availableCategories {
    final List<String> categories = List<String>.from(defaultPredefinedCategories);
    for (final item in allPasswordItems) {
      final cat = item.category.trim();
      if (cat.isNotEmpty && !categories.any((c) => c.toLowerCase() == cat.toLowerCase())) {
        categories.add(cat);
      }
    }
    return categories;
  }

  /// Returns [filteredPasswordItems] grouped by title (case-insensitive) for multi-account rendering
  List<VaultItemGroup> get groupedPasswordItems {
    final Map<String, List<VaultItem>> groupMap = {};
    for (final item in filteredPasswordItems) {
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

  /// Backward-compatible getter for grouped items (strictly password groups)
  List<VaultItemGroup> get groupedItems => groupedPasswordItems;

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
    return 'VaultState(status: $status, allCount: ${allItems.length}, passwords: ${filteredPasswordItems.length}, cards: ${filteredCardItems.length}, groups: ${groupedPasswordItems.length}, category: $selectedCategory, query: "$searchQuery", error: $errorMessage)';
  }
}

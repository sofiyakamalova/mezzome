import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';

class DishesState {
  const DishesState({
    required this.selectedDate,
    this.scheduledItems = const [],
    this.searchQuery = '',
    this.isRefreshing = false,
    this.isMenuCatalogFallback = false,
  });

  final DateTime selectedDate;
  final List<ScheduledMenuItem> scheduledItems;
  final String searchQuery;
  final bool isRefreshing;
  final bool isMenuCatalogFallback;

  List<ScheduledMenuItem> get filteredItems {
    if (searchQuery.trim().isEmpty) {
      return scheduledItems;
    }
    final q = searchQuery.trim().toLowerCase();
    return scheduledItems
        .where((item) => item.name.toLowerCase().contains(q))
        .toList();
  }

  DishesState copyWith({
    DateTime? selectedDate,
    List<ScheduledMenuItem>? scheduledItems,
    String? searchQuery,
    bool? isRefreshing,
    bool? isMenuCatalogFallback,
  }) {
    return DishesState(
      selectedDate: selectedDate ?? this.selectedDate,
      scheduledItems: scheduledItems ?? this.scheduledItems,
      searchQuery: searchQuery ?? this.searchQuery,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isMenuCatalogFallback:
          isMenuCatalogFallback ?? this.isMenuCatalogFallback,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';
import 'package:mezzome/features/dishes/presentation/providers/dishes_state.dart';

class DishesNotifier extends AsyncNotifier<DishesState> {
  @override
  Future<DishesState> build() async {
    return DishesState(selectedDate: DateFormatUtil.today);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    final date = DateFormatUtil.normalizeScheduleDate(
      current?.selectedDate ?? DateFormatUtil.today,
    );
    appLogger.i('Refreshing dishes schedule for ${DateFormatUtil.apiDate(date)}');
    state = AsyncData(
      (current ?? DishesState(selectedDate: date)).copyWith(isRefreshing: true),
    );
    state = await AsyncValue.guard(() => _load(date));
  }

  Future<void> selectDate(DateTime date) async {
    final normalized = DateFormatUtil.normalizeScheduleDate(date);
    appLogger.i('Dishes date selected: ${DateFormatUtil.apiDate(normalized)}');
    final current = state.valueOrNull;
    state = AsyncData(
      DishesState(
        selectedDate: normalized,
        searchQuery: current?.searchQuery ?? '',
        scheduledItems: current?.scheduledItems ?? const [],
        isMenuCatalogFallback: current?.isMenuCatalogFallback ?? false,
      ),
    );
  }

  void setSearchQuery(String query) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(searchQuery: query));
  }

  Future<DishesState> _load(DateTime date, {String searchQuery = ''}) async {
    final scheduleDate = DateFormatUtil.normalizeScheduleDate(date);
    final result = await ref
        .read(dishesRepositoryProvider)
        .fetchScheduleForDate(scheduleDate);

    appLogger.i(
      'Dishes schedule loaded: ${result.items.length} items '
      'for ${DateFormatUtil.apiDate(scheduleDate)}'
      '${result.isMenuCatalogFallback ? ' (owner menu catalog)' : ''}',
    );

    return DishesState(
      selectedDate: scheduleDate,
      scheduledItems: result.items,
      searchQuery: searchQuery,
      isMenuCatalogFallback: result.isMenuCatalogFallback,
    );
  }
}

final dishesNotifierProvider =
    AsyncNotifierProvider<DishesNotifier, DishesState>(
  DishesNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dashboard/data/models/warehouse_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';

/// Складской дашборд («Склад», гайд §9). Период day/week/month/year + meal_period.
/// Данные держим при смене фильтра (`copyWithPrevious`), чтобы не «моргало».
/// Загрузка best-effort: если бэк недоступен, `state.value == null` и UI
/// показывает empty/недоступно вместо краха.
class WarehouseDashboardNotifier extends AsyncNotifier<WarehouseDashboard?> {
  String _period = 'week';
  late final String _date = DateFormatUtil.apiDate(DateFormatUtil.today);
  String _mealPeriod = 'lunch';

  String get period => _period;
  String get mealPeriod => _mealPeriod;

  @override
  Future<WarehouseDashboard?> build() => _load();

  Future<WarehouseDashboard?> _load() => ref
      .read(dashboardRepositoryProvider)
      .fetchWarehouse(period: _period, date: _date, mealPeriod: _mealPeriod);

  Future<void> refresh() async {
    state = const AsyncLoading<WarehouseDashboard?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<void> setPeriod(String period) async {
    if (period == _period) return;
    _period = period;
    state = const AsyncLoading<WarehouseDashboard?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<void> setMealPeriod(String mealPeriod) async {
    if (mealPeriod == _mealPeriod) return;
    _mealPeriod = mealPeriod;
    state = const AsyncLoading<WarehouseDashboard?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final warehouseDashboardNotifierProvider =
    AsyncNotifierProvider<WarehouseDashboardNotifier, WarehouseDashboard?>(
  WarehouseDashboardNotifier.new,
);

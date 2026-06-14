import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';
import 'package:mezzome/features/dashboard/presentation/providers/expenses_state.dart';

/// Грузит расходы за все четыре периода (день/неделя/месяц/год) на одну опорную
/// дату — четыре параллельных запроса `GET /dashboard/expenses`. Границы недели,
/// месяца и года считает backend по `period` + `date`.
class ExpensesNotifier extends AsyncNotifier<ExpensesState> {
  /// Опорная дата (сегодня). Все периоды считаются относительно неё.
  late final String _date = DateFormatUtil.apiDate(DateFormatUtil.today);

  @override
  Future<ExpensesState> build() async {
    return _load(const ExpensesState());
  }

  Future<void> refresh() async {
    final current = state.valueOrNull ?? const ExpensesState();
    state = AsyncData(current.copyWith(isRefreshing: true));
    state = await AsyncValue.guard(() => _load(current));
  }

  /// Выбрать период для разбивки по категориям. Данные уже загружены — сеть
  /// не дёргаем, просто меняем выбор.
  void selectPeriod(ExpensePeriod period) {
    final current = state.valueOrNull;
    if (current == null || current.selected == period) {
      return;
    }
    state = AsyncData(current.copyWith(selected: period));
  }

  Future<ExpensesState> _load(ExpensesState base) async {
    final repo = ref.read(dashboardRepositoryProvider);
    final periods = ExpensePeriod.values;
    final results = await Future.wait(
      periods.map(
        (p) => repo.fetchExpenses(period: p.apiValue, date: _date),
      ),
    );
    final byPeriod = <ExpensePeriod, ExpensesDashboardModel>{
      for (var i = 0; i < periods.length; i++) periods[i]: results[i],
    };
    return base.copyWith(byPeriod: byPeriod, isRefreshing: false);
  }
}

final expensesNotifierProvider =
    AsyncNotifierProvider<ExpensesNotifier, ExpensesState>(
  ExpensesNotifier.new,
);

import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';

/// Периоды расходов, поддерживаемые backend (`day`/`week`/`month`/`year`).
enum ExpensePeriod {
  day('day'),
  week('week'),
  month('month'),
  year('year');

  const ExpensePeriod(this.apiValue);

  final String apiValue;
}

/// Состояние экрана расходов. Данные за все четыре периода грузятся сразу
/// (для карточек день/неделя/месяц/год), а [selected] определяет, чья разбивка
/// по категориям показывается ниже.
class ExpensesState {
  const ExpensesState({
    this.byPeriod = const {},
    this.selected = ExpensePeriod.month,
    this.isRefreshing = false,
  });

  /// Ответ backend по каждому периоду.
  final Map<ExpensePeriod, ExpensesDashboardModel> byPeriod;

  /// Период, выбранный для разбивки по категориям.
  final ExpensePeriod selected;

  final bool isRefreshing;

  ExpensesDashboardModel? get selectedData => byPeriod[selected];

  ExpensesState copyWith({
    Map<ExpensePeriod, ExpensesDashboardModel>? byPeriod,
    ExpensePeriod? selected,
    bool? isRefreshing,
  }) {
    return ExpensesState(
      byPeriod: byPeriod ?? this.byPeriod,
      selected: selected ?? this.selected,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

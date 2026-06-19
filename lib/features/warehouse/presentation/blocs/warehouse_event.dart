part of 'warehouse_bloc.dart';

sealed class WarehouseEvent extends Equatable {
  const WarehouseEvent();

  @override
  List<Object?> get props => [];
}

/// Первичная загрузка / загрузка под текущие параметры.
class WarehouseRequested extends WarehouseEvent {
  const WarehouseRequested();
}

/// Сменили период (day/week/month/year) — перезапросить.
class WarehousePeriodChanged extends WarehouseEvent {
  const WarehousePeriodChanged(this.period);

  final String period;

  @override
  List<Object?> get props => [period];
}

/// Сменили приём пищи (breakfast/lunch/dinner).
class WarehouseMealPeriodChanged extends WarehouseEvent {
  const WarehouseMealPeriodChanged(this.mealPeriod);

  final String mealPeriod;

  @override
  List<Object?> get props => [mealPeriod];
}

/// Pull-to-refresh.
class WarehouseRefreshed extends WarehouseEvent {
  const WarehouseRefreshed();
}

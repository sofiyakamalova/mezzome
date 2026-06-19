part of 'warehouse_bloc.dart';

enum WarehouseStatus { initial, loading, success, failure }

class WarehouseState extends Equatable {
  const WarehouseState({
    this.status = WarehouseStatus.initial,
    this.data,
    this.period = 'week',
    this.mealPeriod = 'lunch',
  });

  final WarehouseStatus status;
  final WarehouseDashboard? data;
  final String period;
  final String mealPeriod;

  bool get isLoading => status == WarehouseStatus.loading;

  WarehouseState copyWith({
    WarehouseStatus? status,
    WarehouseDashboard? data,
    bool clearData = false,
    String? period,
    String? mealPeriod,
  }) {
    return WarehouseState(
      status: status ?? this.status,
      data: clearData ? null : (data ?? this.data),
      period: period ?? this.period,
      mealPeriod: mealPeriod ?? this.mealPeriod,
    );
  }

  @override
  List<Object?> get props => [status, data, period, mealPeriod];
}

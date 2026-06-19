part of 'production_grid_bloc.dart';

/// Состояние недельной сетки меню-борда. Геттеры (rows/days/hasData/...)
/// сохранены как у прежнего ProductionGridState — экран меняется минимально.
class ProductionGridState extends Equatable {
  const ProductionGridState({
    required this.weekStart,
    this.service = MenuServiceType.breakfast,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.grid,
    this.kitchenId,
  });

  final DateTime weekStart;
  final MenuServiceType service;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final ProductionPlanGridResponse? grid;
  final int? kitchenId;

  List<ProductionPlanGridRow> get rows => grid?.rows ?? const [];
  List<ProductionPlanGridDay> get days => grid?.days ?? const [];
  bool get hasData => rows.isNotEmpty || days.isNotEmpty;

  ProductionGridState copyWith({
    DateTime? weekStart,
    MenuServiceType? service,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    ProductionPlanGridResponse? grid,
    bool clearGrid = false,
    int? kitchenId,
  }) {
    return ProductionGridState(
      weekStart: weekStart ?? this.weekStart,
      service: service ?? this.service,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      grid: clearGrid ? null : (grid ?? this.grid),
      kitchenId: kitchenId ?? this.kitchenId,
    );
  }

  @override
  List<Object?> get props =>
      [weekStart, service, isLoading, isRefreshing, errorMessage, grid, kitchenId];
}

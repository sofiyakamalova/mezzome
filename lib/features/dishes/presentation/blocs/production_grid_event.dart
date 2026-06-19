part of 'production_grid_bloc.dart';

sealed class ProductionGridEvent extends Equatable {
  const ProductionGridEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить сетку (опционально с другой опорной датой / принудительно).
class GridLoadRequested extends ProductionGridEvent {
  const GridLoadRequested({this.anchorDate, this.refresh = false});

  final DateTime? anchorDate;
  final bool refresh;

  @override
  List<Object?> get props => [anchorDate, refresh];
}

class GridServiceSelected extends ProductionGridEvent {
  const GridServiceSelected(this.service);

  final MenuServiceType service;

  @override
  List<Object?> get props => [service];
}

class GridWeekShifted extends ProductionGridEvent {
  const GridWeekShifted(this.delta);

  final int delta;

  @override
  List<Object?> get props => [delta];
}

class GridCurrentWeekRequested extends ProductionGridEvent {
  const GridCurrentWeekRequested();
}

class GridRefreshRequested extends ProductionGridEvent {
  const GridRefreshRequested();
}

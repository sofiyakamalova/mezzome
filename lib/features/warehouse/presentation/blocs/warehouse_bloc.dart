import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/warehouse/domain/models/warehouse_dashboard.dart';
import 'package:mezzome/features/warehouse/domain/use_cases/get_warehouse_dashboard_use_case.dart';

part 'warehouse_event.dart';
part 'warehouse_state.dart';

/// BLoC сегмента «Склад». Зависит только от domain (use_case) — не знает про
/// Dio/Retrofit/source. Опорная дата — сегодня; период/приём пищи в состоянии.
class WarehouseBloc extends Bloc<WarehouseEvent, WarehouseState> {
  WarehouseBloc(this._getWarehouse) : super(const WarehouseState()) {
    on<WarehouseRequested>((e, emit) => _load(emit));
    on<WarehouseRefreshed>((e, emit) => _load(emit));
    on<WarehousePeriodChanged>((e, emit) {
      emit(state.copyWith(period: e.period));
      return _load(emit);
    });
    on<WarehouseMealPeriodChanged>((e, emit) {
      emit(state.copyWith(mealPeriod: e.mealPeriod));
      return _load(emit);
    });
  }

  final GetWarehouseDashboardUseCase _getWarehouse;

  final String _date = DateFormatUtil.apiDate(DateFormatUtil.today);

  Future<void> _load(Emitter<WarehouseState> emit) async {
    emit(state.copyWith(status: WarehouseStatus.loading));
    try {
      final data = await _getWarehouse(
        period: state.period,
        date: _date,
        mealPeriod: state.mealPeriod,
      );
      emit(
        state.copyWith(
          status: data == null
              ? WarehouseStatus.failure
              : WarehouseStatus.success,
          data: data,
          clearData: data == null,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: WarehouseStatus.failure, clearData: true));
    }
  }
}

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/domain/use_cases/get_production_grid_use_case.dart';

part 'production_grid_event.dart';
part 'production_grid_state.dart';

/// Роли, у которых есть собственный grid-роут. В двухролевой модели — chef и manager.
const _gridRoles = {UserRole.chef, UserRole.manager};

/// BLoC недельной сетки меню-борда. Роль передаётся при создании (из
/// authSessionProvider на экране). Зависит только от domain (use_case).
class ProductionGridBloc extends Bloc<ProductionGridEvent, ProductionGridState> {
  ProductionGridBloc({
    required GetProductionGridUseCase getGrid,
    required UserRole? role,
  })  : _getGrid = getGrid,
        _role = role,
        super(ProductionGridState(
          weekStart: DateFormatUtil.startOfWeek(DateFormatUtil.today),
        )) {
    on<GridLoadRequested>((e, emit) =>
        _load(emit, anchorDate: e.anchorDate, refresh: e.refresh));
    on<GridServiceSelected>((e, emit) {
      if (e.service == state.service) return Future.value();
      return _load(emit, service: e.service, refresh: true);
    });
    on<GridWeekShifted>((e, emit) => _load(
          emit,
          anchorDate: state.weekStart.add(Duration(days: 7 * e.delta)),
        ));
    on<GridCurrentWeekRequested>(
        (e, emit) => _load(emit, anchorDate: DateFormatUtil.today));
    on<GridRefreshRequested>((e, emit) => _load(emit, refresh: true));
  }

  final GetProductionGridUseCase _getGrid;
  final UserRole? _role;

  Future<void> _load(
    Emitter<ProductionGridState> emit, {
    DateTime? anchorDate,
    MenuServiceType? service,
    bool refresh = false,
  }) async {
    final weekStart = DateFormatUtil.startOfWeek(anchorDate ?? state.weekStart);
    final svc = service ?? state.service;

    final sameWeek = DateFormatUtil.isSameDay(weekStart, state.weekStart);
    if (!refresh &&
        sameWeek &&
        svc == state.service &&
        state.grid != null &&
        !state.isLoading) {
      return;
    }

    // Grid-роут есть только у chef/manager — иначе сразу сообщение, без сети.
    if (!_gridRoles.contains(_role)) {
      appLogger.i('Menu grid: role ${_role?.apiValue} has no grid endpoint');
      emit(state.copyWith(
        weekStart: weekStart,
        service: svc,
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'menuGridForbidden'.tr(),
      ));
      return;
    }

    emit(state.copyWith(
      weekStart: weekStart,
      service: svc,
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
    ));

    final weekStartStr = DateFormatUtil.apiDate(weekStart);
    try {
      final grid = await _getGrid(
        role: _role!,
        weekStart: weekStartStr,
        serviceType: svc.apiValue,
        kitchenId: state.kitchenId,
      );
      emit(state.copyWith(isLoading: false, isRefreshing: false, grid: grid));
    } catch (error, stack) {
      final forbidden =
          error is DioException && error.response?.statusCode == 403;
      appLogger.e('Menu grid load failed', error: error, stackTrace: stack);
      emit(state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage:
            forbidden ? 'menuGridForbidden'.tr() : 'menuGridLoadError'.tr(),
      ));
    }
  }
}

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/presentation/providers/production_grid_state.dart';

/// Грузит недельную сетку меню-борда (`GET /{role}/production-plans/grid`).
///
/// У каждой роли — свой роут: `chef` → `/chef/...`, `supervisor` →
/// `/supervisor/...`, `owner` → `/owner/...`, `manager` → `/manager/...`.
/// У остальных ролей (admin и т.п.) grid-эндпоинта нет — им сразу показываем
/// сообщение «недоступно» вместо заведомо 403-го запроса.
class ProductionGridNotifier extends Notifier<ProductionGridState> {
  @override
  ProductionGridState build() {
    return ProductionGridState(
      //weekStart: DateFormatUtil.startOfWeek(DateFormatUtil.today)
      // ВРЕМЕННО: стартуем на неделе 1–7 июня 2026, где сейчас есть данные.
      // TODO: вернуть `DateFormatUtil.startOfWeek(DateFormatUtil.today)`.
      weekStart: DateFormatUtil.startOfWeek(DateTime(2026, 6, 3)),
    );
  }

  /// Загружает неделю, содержащую [anchorDate] (нормализуется к понедельнику).
  Future<void> load({
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

    final role = ref.read(authSessionProvider).valueOrNull?.role;
    // Grid-роут есть только у chef и manager. Прочие роли (не должны попадать
    // сюда в двухролевой модели) — не дёргаем сеть, сразу показываем сообщение.
    if (!_gridRoles.contains(role)) {
      appLogger.i('Menu grid: role ${role?.apiValue} has no grid endpoint');
      state = state.copyWith(
        weekStart: weekStart,
        service: svc,
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'menuGridForbidden'.tr(),
      );
      return;
    }

    state = state.copyWith(
      weekStart: weekStart,
      service: svc,
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
    );

    final weekStartStr = DateFormatUtil.apiDate(weekStart);
    appLogger.i('Menu grid: week_start=$weekStartStr, service=${svc.apiValue}');

    try {
      final api = ref.read(productionPlansApiProvider);
      // Две роли: manager смотрит сетку через свой роут, chef — через chef-роут.
      final grid = await switch (role!) {
        UserRole.manager => api.getManagerGrid(
          weekStart: weekStartStr,
          serviceType: svc.apiValue,
          kitchenId: state.kitchenId,
        ),
        _ => api.getChefGrid(
          weekStart: weekStartStr,
          serviceType: svc.apiValue,
          kitchenId: state.kitchenId,
        ),
      };

      appLogger.i(
        'Menu grid loaded: ${grid.rows.length} rows, ${grid.days.length} days',
      );

      state = state.copyWith(isLoading: false, isRefreshing: false, grid: grid);
    } catch (error, stack) {
      final forbidden =
          error is DioException && error.response?.statusCode == 403;
      appLogger.e('Menu grid load failed', error: error, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: forbidden
            ? 'menuGridForbidden'.tr()
            : 'menuGridLoadError'.tr(),
      );
    }
  }

  Future<void> selectService(MenuServiceType service) async {
    if (service == state.service) {
      return;
    }
    await load(service: service, refresh: true);
  }

  /// Сдвиг на [deltaWeeks] недель (±1 — соседняя неделя).
  Future<void> shiftWeek(int deltaWeeks) {
    final target = state.weekStart.add(Duration(days: 7 * deltaWeeks));
    return load(anchorDate: target);
  }

  /// Перейти на текущую (сегодняшнюю) неделю.
  Future<void> goToCurrentWeek() => load(anchorDate: DateFormatUtil.today);

  Future<void> refresh() => load(refresh: true);
}

/// Роли, у которых есть собственный grid-роут `/{role}/production-plans/grid`.
/// В двухролевой модели — chef и manager.
const _gridRoles = {UserRole.chef, UserRole.manager};

final productionGridNotifierProvider =
    NotifierProvider<ProductionGridNotifier, ProductionGridState>(
      ProductionGridNotifier.new,
    );

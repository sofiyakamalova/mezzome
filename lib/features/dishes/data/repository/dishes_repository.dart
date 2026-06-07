import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/http_log_utils.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_provider.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/dishes/data/api/dishes_api.dart';
import 'package:mezzome/features/dishes/data/api/production_plans_api.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/plan_variance_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/domain/production_plan_access_denied.dart';
import 'package:mezzome/features/dishes/domain/schedule_fetch_result.dart';

class DishesRepository {
  DishesRepository({
    required DishesApi dishesApi,
    required ProductionPlansApi productionPlansApi,
    required Ref ref,
  })  : _dishesApi = dishesApi,
        _productionPlansApi = productionPlansApi,
        _ref = ref;

  final DishesApi _dishesApi;
  final ProductionPlansApi _productionPlansApi;
  final Ref _ref;

  /// Текущий пользователь ходит по директорским (manager) ручкам, а не chef.
  /// Используется для выбора `/manager/...` vs `/chef/...` эндпоинтов.
  bool get usesManagerApi {
    final role = _ref.read(authSessionProvider).valueOrNull?.role;
    return role != null && usesDirectorShell(role);
  }

  /// Меню на дату через production plans (chef / supervisor API).
  ///
  /// [serviceType] — фильтр `service_type` в list (breakfast / lunch / dinner).
  /// Для дашборда недели передавайте выбранный приём пищи — один план на день.
  Future<ScheduleFetchResult> fetchScheduleForDate(
    DateTime date, {
    MenuServiceType? serviceType,
  }) async {
    final role = _ref.read(authSessionProvider).valueOrNull?.role;
    if (role == null) {
      return const ScheduleFetchResult(items: []);
    }

    final dateStr = DateFormatUtil.apiDate(date);
    final useChefApi = _useChefProductionPlansApi(role);
    appLogger.i(
      'Loading production plans for $dateStr '
      '(${useChefApi ? 'chef' : 'supervisor'}, role=${role.apiValue})',
    );

    try {
      final items = await _loadFromProductionPlans(
        dateStr: dateStr,
        role: role,
        preferChefApi: useChefApi,
        serviceType: serviceType?.apiValue,
      );
      return ScheduleFetchResult(items: items);
    } on ProductionPlanAccessDenied {
      if (role != UserRole.owner) {
        rethrow;
      }
      appLogger.i(
        'Owner: production plans FORBIDDEN — fallback to GET /owner/menu/items',
      );
      final items = await _loadOwnerMenuCatalog();
      return ScheduleFetchResult(items: items, isMenuCatalogFallback: true);
    }
  }

  Future<List<ScheduledMenuItem>> _loadFromProductionPlans({
    required String dateStr,
    required UserRole role,
    required bool preferChefApi,
    String? serviceType,
  }) async {
    final fetched = await _fetchProductionPlanList(
      dateStr: dateStr,
      role: role,
      preferChefApi: preferChefApi,
      serviceType: serviceType,
    );
    final list = fetched.list;
    final resolvedChefApi = fetched.usedChefApi;

    if (list.plans.isEmpty) {
      appLogger.i('No production plans for $dateStr');
      return [];
    }

    final nameById = await _loadMenuItemNames(role);
    final scheduled = <ScheduledMenuItem>[];

    for (final plan in list.plans) {
      final detail = resolvedChefApi
          ? await _productionPlansApi.getChefPlan(plan.id)
          : await _productionPlansApi.getSupervisorPlan(plan.id);

      for (final item in detail.items) {
        scheduled.add(
          ScheduledMenuItem(
            menuItemId: item.menuItemId,
            name: nameById[item.menuItemId] ??
                'dishFallbackName'.tr(namedArgs: {'id': '${item.menuItemId}'}),
            plannedPortions: item.plannedPortions,
            serviceType: plan.serviceType ?? detail.serviceType ?? '—',
            planStatus: plan.status ?? detail.status ?? '—',
            theoreticalCost: item.theoreticalCost,
            planItemId: item.id,
            planId: detail.id,
            technicalCardId: item.technicalCardId,
          ),
        );
      }
    }

    appLogger.i(
      'Production plan loaded: ${scheduled.length} items for $dateStr',
    );
    return scheduled;
  }

  Future<List<ScheduledMenuItem>> _loadOwnerMenuCatalog() async {
    final response = await _dishesApi.getOwnerMenuItems();
    final items = response.items
        .where((dish) => dish.isActive && dish.isAvailable)
        .map(
          (dish) => ScheduledMenuItem(
            menuItemId: dish.id,
            name: dish.name,
            plannedPortions: 0,
            serviceType: '—',
            planStatus: 'menu_catalog',
            theoreticalCost: dish.costPerPortion,
          ),
        )
        .toList();
    appLogger.i('Owner menu catalog: ${items.length} items');
    return items;
  }

  Future<Map<int, String>> _loadMenuItemNames(UserRole role) async {
    final response = canOpenDirectorDashboard(role)
        ? await _dishesApi.getOwnerMenuItems()
        : await _dishesApi.getCommonMenuItems();

    return {for (final dish in response.items) dish.id: dish.name};
  }

  /// Каталог всех блюд (fallback / справочник).
  Future<List<DishModel>> fetchCatalogDishes() async {
    final role = _ref.read(authSessionProvider).valueOrNull?.role;
    if (role == null) {
      return [];
    }

    final response = canOpenDirectorDashboard(role)
        ? await _dishesApi.getOwnerMenuItems()
        : await _dishesApi.getCommonMenuItems();
    return response.items;
  }

  /// Кухни, доступные для создания плана. Менеджер выбирает из списка
  /// (`GET /kitchens`); chef привязан к одной (`GET /chef/kitchens/current`),
  /// возвращаем её единственным элементом — форма сама решает, показывать
  /// выбор или статичную подпись.
  Future<List<KitchenModel>> planKitchens() async {
    final role = _ref.read(authSessionProvider).valueOrNull?.role;
    final asManager = role != null && usesDirectorShell(role);
    if (!asManager) {
      final kitchen = await _productionPlansApi.getChefCurrentKitchen();
      appLogger.i('Chef current kitchen: ${kitchen.id} (${kitchen.name})');
      return [kitchen];
    }
    final raw = await _productionPlansApi.getKitchens();
    final list = _parseKitchens(raw);
    appLogger.i('Manager kitchens: ${list.length}');
    return list;
  }

  /// Лояльный разбор `GET /kitchens`: принимает голый список или обёртку
  /// `items`/`kitchens`/`data`; берёт `id` (+`name`), пропускает мусор.
  List<KitchenModel> _parseKitchens(dynamic raw) {
    List<dynamic>? items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      final m = raw.map((k, v) => MapEntry('$k', v));
      items = (m['items'] ?? m['kitchens'] ?? m['data']) as List<dynamic>?;
    }
    if (items == null) return const [];
    return items
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .where((e) => e['id'] != null)
        .map(
          (e) => KitchenModel(
            id: (e['id'] as num).toInt(),
            name: e['name'] as String?,
          ),
        )
        .toList();
  }

  /// Отчёт «план vs факт» (заложено vs забрали) для дашборда менеджера: берёт
  /// план выбранного дня (`getManagerPlans`) и его `variance-report`.
  /// Возвращает `null`, если роль не manager, плана за день нет или ручка
  /// недоступна — UI просто не показывает секцию (без ошибки).
  Future<PlanVarianceReport?> loadManagerDayVariance({DateTime? date}) async {
    final role = _ref.read(authSessionProvider).valueOrNull?.role;
    if (role != UserRole.manager) {
      return null;
    }
    final dateStr = DateFormatUtil.apiDate(date ?? DateFormatUtil.today);
    try {
      final plans =
          await _productionPlansApi.getManagerPlans(dateStr, pageSize: 1);
      if (plans.plans.isEmpty) {
        appLogger.i('Manager variance: no plan for $dateStr');
        return null;
      }
      final plan = plans.plans.first;
      final raw = await _productionPlansApi.getManagerPlanVarianceReport(
        plan.id,
        includeLoss: true,
      );
      final report = PlanVarianceReport.fromJson(raw, planId: plan.id);
      appLogger.i(
        'Manager variance plan ${plan.id}: ${report.lines.length} lines, '
        'varianceCost=${report.varianceCost}',
      );
      return report;
    } on DioException catch (error) {
      appLogger.w(
        'Manager variance load failed '
        '(HTTP ${error.response?.statusCode}): ${error.message}',
      );
      return null;
    }
  }

  /// Создаёт производственный план. Менеджер шлёт на свою ручку
  /// (`POST /manager/production-plans`), chef — на `POST /chef/production-plans`.
  /// Тело запроса у обеих ручек одинаковое.
  Future<ProductionPlanDetail> createProductionPlan(
    ProductionPlanCreateRequest request,
  ) async {
    final role = _ref.read(authSessionProvider).valueOrNull?.role;
    final asManager = role != null && usesDirectorShell(role);
    appLogger.i(
      'Create plan (${asManager ? 'manager' : 'chef'}): '
      'kitchen=${request.kitchenId}, service=${request.serviceType}, '
      'date=${request.plannedDate}, items=${request.items.length}',
    );
    final plan = asManager
        ? await _productionPlansApi.createManagerPlan(request)
        : await _productionPlansApi.createChefPlan(request);
    appLogger.i('Plan created: id=${plan.id}, status=${plan.status}');
    return plan;
  }

  /// Проверка остатков по плану. Возвращает «хватает/не хватает» и число
  /// дефицитных позиций (форма ответа нетипизирована — парсим лояльно).
  Future<({bool canFulfill, int shortages})> checkStock(int planId) async {
    final role = _ref.read(authSessionProvider).valueOrNull?.role;
    final asManager = role != null && usesDirectorShell(role);
    final raw = asManager
        ? await _productionPlansApi.checkManagerPlanStock(planId)
        : await _productionPlansApi.checkChefPlanStock(planId);
    var canFulfill = false;
    var shortages = 0;
    if (raw is Map) {
      final m = raw.map((k, v) => MapEntry('$k', v));
      canFulfill = m['can_fulfill'] == true || m['stock_available'] == true;
      final sh = m['shortages'];
      if (sh is List) shortages = sh.length;
    }
    appLogger.i(
      'Plan $planId stock check: can_fulfill=$canFulfill, shortages=$shortages',
    );
    return (canFulfill: canFulfill, shortages: shortages);
  }

  /// Планы для очереди утверждения супервайзера на дату.
  Future<List<ProductionPlanListItem>> supervisorPlans({
    required DateTime date,
    String? status,
  }) async {
    final res = await _productionPlansApi.getSupervisorPlans(
      DateFormatUtil.apiDate(date),
      status: status,
      pageSize: _productionPlansPageSize,
    );
    appLogger.i('Supervisor plans (${DateFormatUtil.apiDate(date)}): '
        '${res.plans.length}');
    return res.plans;
  }

  Future<void> approvePlan(int id, {bool force = false}) async {
    await _productionPlansApi
        .approveSupervisorPlan(id, <String, dynamic>{'force': force});
    appLogger.i('Plan $id approved (force=$force)');
  }

  Future<void> conditionalApprovePlan(int id, {required String reason}) async {
    await _productionPlansApi.conditionalApproveSupervisorPlan(
      id,
      <String, dynamic>{'reason': reason, 'override_reason': reason},
    );
    appLogger.i('Plan $id conditionally approved');
  }

  Future<void> rejectPlan(int id, {required String reason}) async {
    await _productionPlansApi
        .rejectSupervisorPlan(id, <String, dynamic>{'reason': reason});
    appLogger.i('Plan $id rejected');
  }

  static const int _productionPlansPageSize = 50;

  Future<({ProductionPlanListResponse list, bool usedChefApi})>
      _fetchProductionPlanList({
    required String dateStr,
    required UserRole role,
    required bool preferChefApi,
    String? serviceType,
  }) async {
    if (preferChefApi) {
      final list = await _productionPlansApi.getChefPlans(
        dateStr,
        serviceType: serviceType,
        pageSize: _productionPlansPageSize,
      );
      return (list: list, usedChefApi: true);
    }

    // Менеджер — свои manager-ручки планов (бэкенд добавил аналоги chef).
    if (role == UserRole.manager) {
      final list = await _productionPlansApi.getManagerPlans(
        dateStr,
        serviceType: serviceType,
        pageSize: _productionPlansPageSize,
      );
      return (list: list, usedChefApi: false);
    }

    try {
      final list = await _productionPlansApi.getSupervisorPlans(
        dateStr,
        serviceType: serviceType,
        pageSize: _productionPlansPageSize,
      );
      return (list: list, usedChefApi: false);
    } on DioException catch (error) {
      if (role != UserRole.owner || !isApiForbidden(error)) {
        rethrow;
      }

      appLogger.w(
        'Supervisor production-plans FORBIDDEN for owner, trying chef API. '
        'Raw: ${formatRawHttpPayload(error.response?.data)}',
      );

      try {
        final list = await _productionPlansApi.getChefPlans(
          dateStr,
          serviceType: serviceType,
          pageSize: _productionPlansPageSize,
        );
        return (list: list, usedChefApi: true);
      } on DioException catch (chefError) {
        if (isApiForbidden(chefError)) {
          appLogger.w(
            'Chef production-plans FORBIDDEN for owner. '
            'Raw: ${formatRawHttpPayload(chefError.response?.data)}',
          );
          throw ProductionPlanAccessDenied(
            apiError: apiErrorCode(chefError) ?? 'FORBIDDEN',
          );
        }
        rethrow;
      }
    }
  }
}

bool _useChefProductionPlansApi(UserRole role) {
  return isKitchenStaff(role) && !canOpenDirectorDashboard(role);
}

final dishesApiProvider = Provider<DishesApi>((ref) {
  return DishesApi(ref.watch(dioProvider));
});

final productionPlansApiProvider = Provider<ProductionPlansApi>((ref) {
  return ProductionPlansApi(ref.watch(dioProvider));
});

final dishesRepositoryProvider = Provider<DishesRepository>((ref) {
  return DishesRepository(
    dishesApi: ref.watch(dishesApiProvider),
    productionPlansApi: ref.watch(productionPlansApiProvider),
    ref: ref,
  );
});

/// «План vs факт» по плану текущего дня — для секции на дашборде менеджера.
final managerDayVarianceProvider =
    FutureProvider.autoDispose<PlanVarianceReport?>((ref) {
  return ref.watch(dishesRepositoryProvider).loadManagerDayVariance();
});

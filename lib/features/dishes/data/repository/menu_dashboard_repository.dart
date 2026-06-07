import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/network/dio_provider.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/data/api/ingredients_api.dart';
import 'package:mezzome/features/dishes/data/api/production_plans_api.dart';
import 'package:mezzome/features/dishes/data/api/technical_cards_api.dart';
import 'package:mezzome/features/dishes/data/models/ingredient_catalog_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/domain/plan_not_editable.dart';
import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';
import 'package:mezzome/features/dishes/domain/tech_card_history.dart';

class WeekScheduleDay {
  const WeekScheduleDay({
    required this.date,
    required this.items,
  });

  final DateTime date;
  final List<ScheduledMenuItem> items;
}

class MenuDashboardRepository {
  MenuDashboardRepository({
    required DishesRepository dishesRepository,
    required TechnicalCardsApi technicalCardsApi,
    required ProductionPlansApi productionPlansApi,
    required IngredientsApi ingredientsApi,
  })  : _dishesRepository = dishesRepository,
        _technicalCardsApi = technicalCardsApi,
        _productionPlansApi = productionPlansApi,
        _ingredientsApi = ingredientsApi;

  final DishesRepository _dishesRepository;
  final TechnicalCardsApi _technicalCardsApi;
  final ProductionPlansApi _productionPlansApi;
  final IngredientsApi _ingredientsApi;

  /// One column in the grid — only the date selected in the calendar.
  List<DateTime> gridDaysForSelectedDate(DateTime selected) {
    final day = DateFormatUtil.normalizeScheduleDate(selected);
    return [day];
  }

  /// Production plans for a single day and service (one list + detail calls).
  Future<List<WeekScheduleDay>> fetchDaySchedule(
    DateTime date, {
    required MenuServiceType service,
  }) async {
    final normalized = DateFormatUtil.normalizeScheduleDate(date);
    final result = await _dishesRepository.fetchScheduleForDate(
      normalized,
      serviceType: service,
    );
    return [WeekScheduleDay(date: normalized, items: result.items)];
  }

  List<ScheduledMenuItem> itemsForService(
    List<WeekScheduleDay> week,
    MenuServiceType service,
  ) {
    return week
        .expand((day) => day.items)
        .where((item) => service.matchesApiValue(item.serviceType))
        .toList();
  }

  Map<int, double> consumptionByDayIndex(
    List<WeekScheduleDay> week,
    MenuServiceType service,
  ) {
    final map = <int, double>{};
    for (var i = 0; i < week.length; i++) {
      final total = week[i].items
          .where((item) => service.matchesApiValue(item.serviceType))
          .fold<double>(
            0,
            (sum, item) =>
                sum + (item.theoreticalCost ?? 0) * item.plannedPortions,
          );
      map[i] = total;
    }
    return map;
  }

  /// Список техкарт под текущую роль: manager → `/manager/technical-cards`,
  /// chef → `/chef/technical-cards` (chef-роуты менеджеру отвечают 403).
  Future<TechnicalCardListResponse> _listTechnicalCards({
    String? search,
    String? status,
    bool? includeAllVersions,
  }) {
    if (_dishesRepository.usesManagerApi) {
      return _technicalCardsApi.listManagerTechnicalCards(
        search: search,
        status: status,
        includeAllVersions: includeAllVersions,
      );
    }
    return _technicalCardsApi.listTechnicalCards(
      search: search,
      status: status,
      includeAllVersions: includeAllVersions,
    );
  }

  Future<TechnicalCardModel?> findTechnicalCardByName(String name) async {
    if (name.trim().isEmpty) {
      return null;
    }
    try {
      // include_all_versions: head-список может быть переименован/в pending,
      // а нам нужна версия, чьё имя совпадает с названием блюда из сетки.
      final response = await _listTechnicalCards(
        search: name,
        includeAllVersions: true,
      );
      if (response.cards.isEmpty) {
        return null;
      }
      final lower = name.toLowerCase();
      final nameMatches =
          response.cards.where((c) => c.name.toLowerCase() == lower).toList();
      final pool = nameMatches.isNotEmpty ? nameMatches : response.cards;
      // Предпочитаем утверждённую версию (для сетки — действующее меню).
      final summary = pool.firstWhere(
        (c) => (c.status ?? '').toLowerCase() == 'approved',
        orElse: () => pool.first,
      );
      final detail = await getTechnicalCard(summary.id);
      if (detail != null) {
        return detail;
      }
      appLogger.w(
        'Technical card ${summary.id}: detail API failed, using list summary',
      );
      return summary;
    } on DioException catch (error) {
      appLogger.w('Technical cards search failed: ${error.message}');
      return null;
    }
  }

  /// Резолвит техкарту по `menu_item_id` (когда grid не дал technical_card_id).
  /// Тянет список всех версий и выбирает карту с этим блюдом (предпочитая
  /// утверждённую), затем грузит её detail с ингредиентами.
  Future<TechnicalCardModel?> findTechnicalCardByMenuItem(int menuItemId) async {
    try {
      final response = await _listTechnicalCards(
        includeAllVersions: true,
      );
      final matches =
          response.cards.where((c) => c.menuItemId == menuItemId).toList();
      if (matches.isEmpty) {
        appLogger.i('No technical card for menu_item_id=$menuItemId');
        return null;
      }
      final summary = matches.firstWhere(
        (c) => (c.status ?? '').toLowerCase() == 'approved',
        orElse: () => matches.first,
      );
      appLogger.i(
        'Technical card ${summary.id} matched by menu_item_id=$menuItemId',
      );
      return await getTechnicalCard(summary.id) ?? summary;
    } on DioException catch (error) {
      appLogger.w('Tech card by menu_item_id failed: ${error.message}');
      return null;
    }
  }

  /// List/search omits ingredients — load detail by id when possible.
  Future<TechnicalCardModel?> loadTechnicalCardFull(int id) async {
    final detail = await getTechnicalCard(id);
    if (detail != null) {
      appLogger.i(
        'Technical card $id loaded: ${detail.ingredients.length} ingredients, '
        'food_cost=${detail.foodCost}',
      );
      return detail;
    }
    try {
      final response = await _listTechnicalCards();
      TechnicalCardModel? summary;
      for (final card in response.cards) {
        if (card.id == id) {
          summary = card;
          break;
        }
      }
      if (summary != null) {
        appLogger.w(
          'Technical card $id: detail API failed, using list summary',
        );
        return summary;
      }
    } on DioException catch (error) {
      appLogger.w('Technical cards list fallback failed: ${error.message}');
    }
    return null;
  }

  /// История версий техкарты (`GET /chef/technical-cards/{id}/history`):
  /// кто/когда/что менял. Ответ не типизирован — парсим лояльно.
  ///
  /// Роут chef-only: у manager/owner/supervisor вернёт 403 — в этом случае
  /// помечаем результат [TechCardHistoryResult.forbidden], чтобы UI показал
  /// «нет доступа», а не пустую историю. Прочие ошибки → пустой результат.
  Future<TechCardHistoryResult> loadTechnicalCardHistory(int id) async {
    try {
      final raw = await (_dishesRepository.usesManagerApi
          ? _technicalCardsApi.getManagerTechnicalCardHistory(id)
          : _technicalCardsApi.getTechnicalCardHistory(id));
      final entries = parseTechCardHistory(raw);
      appLogger.i('Tech card $id history: ${entries.length} entries');
      return TechCardHistoryResult(entries: entries);
    } on DioException catch (error) {
      final forbidden = isApiForbidden(error);
      appLogger.w(
        'Tech card $id history failed'
        '${forbidden ? ' (FORBIDDEN)' : ''}: ${error.message}',
      );
      return TechCardHistoryResult(forbidden: forbidden);
    }
  }

  Future<TechnicalCardModel?> getTechnicalCard(int id) async {
    try {
      return await (_dishesRepository.usesManagerApi
          ? _technicalCardsApi.getManagerTechnicalCard(id)
          : _technicalCardsApi.getTechnicalCard(id));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      appLogger.w(
        'Technical card $id load failed'
        '${status != null ? ' (HTTP $status)' : ''}: ${error.message}',
      );
      return null;
    }
  }

  Future<TechnicalCardModel?> saveTechnicalCard({
    required int id,
    required TechCardDraft draft,
    bool submitForApproval = false,
  }) async {
    try {
      appLogger.i(
        'PATCH technical-card $id: name="${draft.name}", '
        'base_portions=${draft.portions}, output=${draft.outputGrams}, '
        'menu_item_id=${draft.menuItemId}, ingredients=${draft.ingredients.length}, '
        'submit_for_approval=$submitForApproval',
      );
      final asManager = _dishesRepository.usesManagerApi;
      final request =
        UpdateTechnicalCardRequest(
          name: draft.name,
          description: draft.notes.isEmpty ? null : draft.notes,
          basePortions: draft.portions.toDouble(),
          outputPerPortion: draft.outputGrams,
          outputUnit: 'g',
          menuItemId: draft.menuItemId,
          halalRequired: draft.halalRequired,
          submitForApproval: submitForApproval,
          // Бэкенд ждёт ingredient_id + граммовки; цену (cost_per_unit)
          // не отправляем — себестоимость считается из справочника.
          ingredients: draft.ingredients
              .asMap()
              .entries
              .map(
                (entry) => TechnicalCardIngredientInput(
                  ingredientId: entry.value.ingredientId,
                  brutto: entry.value.brutto,
                  netto: entry.value.netto,
                  sortOrder: entry.key,
                ),
              )
              .toList(),
        );
      final result = await (asManager
          ? _technicalCardsApi.updateManagerTechnicalCard(id, request)
          : _technicalCardsApi.updateTechnicalCard(id, request));
      appLogger.i(
        'PATCH technical-card $id OK: status=${result.status}, '
        'version=${result.version}, approval=${result.approvalStatus}',
      );
      return result;
    } on DioException catch (error) {
      appLogger.w(
        'Technical card save failed (HTTP ${error.response?.statusCode}): '
        '${error.response?.data ?? error.message}',
      );
      rethrow;
    }
  }

  /// Само-подтверждение техкарты шефом (`POST /chef/technical-cards/{id}/approve`):
  /// одобряет черновую версию без отправки на согласование. Изменение
  /// фиксируется бэкендом в истории техкарты.
  Future<TechnicalCardModel?> approveTechnicalCard(int id) async {
    final result = await (_dishesRepository.usesManagerApi
        ? _technicalCardsApi.approveManagerTechnicalCard(id)
        : _technicalCardsApi.approveTechnicalCard(id));
    appLogger.i(
      'Technical card $id self-approved: status=${result.status}, '
      'version=${result.version}, approval=${result.approvalStatus}',
    );
    return result;
  }

  /// Меняет количество порций ячейки недельного плана
  /// (`PATCH /{role}/production-plan-items/{planItemId}`). Это отдельная от
  /// техкарты сущность — `base_portions` сюда не относится.
  ///
  /// [asManager] — слать на manager-ручку (`/manager/production-plan-items`):
  /// директор составляет план через сетку. Иначе — chef-ручка.
  ///
  /// Бросает [PlanNotEditable], если backend ответил `PLAN_NOT_EDITABLE`
  /// (производство по ячейке уже началось).
  Future<ProductionPlanItem> updatePlannedPortions({
    required int planItemId,
    bool asManager = false,
    int? plannedPortions,
    int? menuItemId,
    String? slotKey,
    String? slotTitle,
    int? sortOrder,
  }) async {
    try {
      final request = UpdateProductionPlanItemRequest(
        plannedPortions: plannedPortions,
        menuItemId: menuItemId,
        slotKey: slotKey,
        slotTitle: slotTitle,
        sortOrder: sortOrder,
      );
      return await (asManager
          ? _productionPlansApi.updateManagerProductionPlanItem(
              planItemId, request)
          : _productionPlansApi.updateProductionPlanItem(planItemId, request));
    } on DioException catch (error) {
      if (apiErrorCode(error) == PlanNotEditable.code) {
        appLogger.w('Plan item $planItemId not editable (production started)');
        throw const PlanNotEditable();
      }
      appLogger.w('Planned portions update failed: ${error.message}');
      rethrow;
    }
  }

  /// Справочник ингредиентов кухни — для ручного выбора `ingredient_id` в
  /// редакторе техкарты. Кухню берём через [DishesRepository.planKitchens]
  /// (chef → его текущая `chef/kitchens/current`; manager → первая из `/kitchens`,
  /// chef-роут менеджеру отвечает 403), затем тянем её ингредиенты.
  Future<List<IngredientCatalogItem>> loadIngredientCatalog() async {
    final kitchens = await _dishesRepository.planKitchens();
    if (kitchens.isEmpty) {
      appLogger.w('Ingredient catalog: no kitchen available');
      return const [];
    }
    final kitchen = kitchens.first;
    final items = await _ingredientsApi.getKitchenIngredients(kitchen.id);
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    appLogger.i(
      'Ingredient catalog: ${items.length} items (kitchen ${kitchen.id})',
    );
    return items;
  }

  /// Ингредиенты блюда → строки техкарты с готовыми `ingredient_id`.
  /// Полуфабрикаты (`isPreparation`) тоже возвращаем, но без id — редактор
  /// пометит их как требующие выбора, а клиентская валидация не даст сохранить.
  Future<List<TechCardIngredientDraft>> loadDishIngredients(
    int menuItemId,
  ) async {
    final dishIngredients =
        await _ingredientsApi.getMenuItemIngredients(menuItemId);
    appLogger.i(
      'Dish $menuItemId ingredients: ${dishIngredients.length} '
      '(${dishIngredients.where((e) => e.isPreparation).length} preparations)',
    );
    return dishIngredients
        .map(
          (e) => TechCardIngredientDraft(
            ingredientId: e.ingredientId,
            name: e.name,
            brutto: e.brutto,
            netto: e.netto,
            pricePerKg: e.costPerUnit,
          ),
        )
        .toList();
  }

  TechCardDraft draftFromTechnicalCard(
    TechnicalCardModel card, {
    required String serviceLabel,
    required String dayLabel,
    required String categoryLabel,
    bool scheduleless = false,
    int? plannedPortions,
    int? planItemId,
    int? menuItemId,
  }) {
    final portions = card.basePortions <= 0 ? 1 : card.basePortions.round();
    final serverCost = _serverCostPerPortion(card);
    final draft = TechCardDraft(
      id: card.id,
      name: card.name,
      serviceLabel: serviceLabel,
      dayLabel: dayLabel,
      categoryLabel: categoryLabel,
      outputGrams: card.outputPerPortion,
      portions: portions,
      plannedPortions: plannedPortions,
      planItemId: planItemId,
      menuItemId: menuItemId ?? card.menuItemId,
      notes: card.description ?? '',
      serverCostPerPortion: serverCost,
      scheduleless: scheduleless,
      readOnly: card.isReadOnly,
      version: card.version,
      changeLevel: card.changeLevel,
      submittedAt: card.submittedAt,
      approvedAt: card.approvedAt,
      halalRequired: card.halalRequired,
      ingredients: card.ingredients
          .map(
            (ing) => TechCardIngredientDraft(
              id: ing.id,
              ingredientId: ing.ingredientId,
              name: ing.ingredientName ?? '',
              brutto: ing.brutto,
              netto: ing.netto,
              pricePerKg: ing.costPerUnit,
            ),
          )
          .toList(),
    );
    draft.originalSnapshot = draft.copyForSnapshot();
    return draft;
  }

  static double? _serverCostPerPortion(TechnicalCardModel card) {
    if (card.foodCost > 0) {
      return card.foodCost;
    }
    if (card.basePortions > 0 && card.totalIngredientCost > 0) {
      return card.totalIngredientCost / card.basePortions;
    }
    return null;
  }

  TechCardDraft draftFromScheduledItem(
    ScheduledMenuItem item, {
    required String serviceLabel,
    required String dayLabel,
  }) {
    final draft = TechCardDraft(
      name: item.name,
      serviceLabel: serviceLabel,
      dayLabel: dayLabel,
      categoryLabel: item.name,
      portions: item.plannedPortions <= 0 ? 1 : item.plannedPortions,
      plannedPortions: item.plannedPortions <= 0 ? null : item.plannedPortions,
      planItemId: item.planItemId,
      menuItemId: item.menuItemId,
      ingredients: [
        TechCardIngredientDraft(name: item.name, netto: 100, pricePerKg: 0),
      ],
    );
    if (item.theoreticalCost != null) {
      draft.ingredients.first.pricePerKg = item.theoreticalCost! * 10;
      draft.ingredients.first.netto = 100;
    }
    draft.originalSnapshot = draft.copyForSnapshot();
    return draft;
  }
}

final technicalCardsApiProvider = Provider<TechnicalCardsApi>((ref) {
  return TechnicalCardsApi(ref.watch(dioProvider));
});

final ingredientsApiProvider = Provider<IngredientsApi>((ref) {
  return IngredientsApi(ref.watch(dioProvider));
});

final menuDashboardRepositoryProvider = Provider<MenuDashboardRepository>((ref) {
  return MenuDashboardRepository(
    dishesRepository: ref.watch(dishesRepositoryProvider),
    technicalCardsApi: ref.watch(technicalCardsApiProvider),
    productionPlansApi: ref.watch(productionPlansApiProvider),
    ingredientsApi: ref.watch(ingredientsApiProvider),
  );
});

/// Справочник ингредиентов кухни — кэшируется на сессию (источник для пикера).
final ingredientCatalogProvider =
    FutureProvider<List<IngredientCatalogItem>>((ref) {
  return ref.watch(menuDashboardRepositoryProvider).loadIngredientCatalog();
});

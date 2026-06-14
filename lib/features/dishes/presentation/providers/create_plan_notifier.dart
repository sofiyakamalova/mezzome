import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/presentation/providers/create_plan_state.dart';

/// Управляет составлением производственного плана: справочники (кухни, каталог
/// блюд, категории-слоты), черновик строк, валидация и отправка с разбором
/// ошибок. Слот строки = категория выбранного блюда.
class CreatePlanNotifier extends Notifier<CreatePlanState> {
  int _nextKey = 0;

  @override
  CreatePlanState build() {
    final initial = CreatePlanState(
      date: DateFormatUtil.today,
      items: [PlanDraftItem(key: _nextKey++)],
    );
    _bootstrap();
    return initial;
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(dishesRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.planKitchens(),
        repo.fetchCatalogDishes(),
        repo.fetchMenuCategories(),
      ]);
      final kitchens = results[0] as List<KitchenModel>;
      state = state.copyWith(
        isBootstrapping: false,
        kitchens: kitchens,
        kitchenId: kitchens.isNotEmpty ? kitchens.first.id : null,
        catalog: results[1] as List<DishModel>,
        categories: results[2] as List<MenuCategoryModel>,
        clearBootstrapError: true,
      );
    } on DioException catch (e) {
      appLogger.w('Create plan bootstrap failed: ${e.message}');
      state = state.copyWith(
        isBootstrapping: false,
        bootstrapError: apiErrorDetails(e) ?? e.message ?? 'unknown',
      );
    } catch (e) {
      appLogger.w('Create plan bootstrap failed: $e');
      state = state.copyWith(
        isBootstrapping: false,
        bootstrapError: e.toString(),
      );
    }
  }

  Future<void> retryBootstrap() async {
    state = state.copyWith(isBootstrapping: true, clearBootstrapError: true);
    await _bootstrap();
  }

  void setService(MenuServiceType service) =>
      state = state.copyWith(service: service);

  void setDate(DateTime date) => state = state.copyWith(date: date);

  void setKitchen(int? kitchenId) =>
      state = state.copyWith(kitchenId: kitchenId);

  void setPeopleCount(int? value) => state = value == null
      ? state.copyWith(clearPeopleCount: true)
      : state.copyWith(peopleCount: value);

  void setReserveCoefficient(double? value) => state = value == null
      ? state.copyWith(clearReserve: true)
      : state.copyWith(reserveCoefficient: value);

  void setNotes(String? value) =>
      state = state.copyWith(notes: (value ?? '').trim());

  void addItem() {
    state = state.copyWith(
      items: [...state.items, PlanDraftItem(key: _nextKey++)],
    );
  }

  void removeItem(int key) {
    final next = state.items.where((i) => i.key != key).toList();
    state = state.copyWith(
      items: next.isEmpty ? [PlanDraftItem(key: _nextKey++)] : next,
    );
  }

  void setItemDish(int key, int? menuItemId) {
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.key == key)
            PlanDraftItem(key: i.key, menuItemId: menuItemId, portions: i.portions)
          else
            i,
      ],
    );
  }

  void setItemPortions(int key, int? portions) {
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.key == key)
            PlanDraftItem(
              key: i.key,
              menuItemId: i.menuItemId,
              portions: portions,
            )
          else
            i,
      ],
    );
  }

  /// Сброс формы после успешного создания (новый пустой черновик).
  void reset() {
    state = state.copyWith(
      items: [PlanDraftItem(key: _nextKey++)],
      clearPeopleCount: true,
      clearReserve: true,
      notes: '',
      clearSubmitError: true,
      fieldErrors: const {},
      clearCreatedPlan: true,
    );
  }

  /// Создаёт план. Возвращает созданный план или null при ошибке (ошибка
  /// также кладётся в state для показа в UI).
  Future<ProductionPlanDetail?> submit() async {
    final kitchenId = state.kitchenId;
    final filled = state.filledItems;
    if (kitchenId == null || filled.isEmpty) {
      return null;
    }

    final categoryById = {for (final c in state.categories) c.id: c};
    final dishById = {for (final d in state.catalog) d.id: d};

    final inputs = <ProductionPlanItemInput>[];
    for (var i = 0; i < filled.length; i++) {
      final item = filled[i];
      final dish = dishById[item.menuItemId];
      final category =
          dish?.categoryId != null ? categoryById[dish!.categoryId] : null;
      inputs.add(
        ProductionPlanItemInput(
          menuItemId: item.menuItemId!,
          plannedPortions: item.portions!,
          slotKey: category != null ? 'category_${category.id}' : null,
          slotTitle: category?.name,
          sortOrder: category?.sortOrder ?? (i + 1),
        ),
      );
    }

    final request = ProductionPlanCreateRequest(
      kitchenId: kitchenId,
      serviceType: state.service.apiValue,
      plannedDate: DateFormatUtil.apiDate(state.date),
      peopleCount: state.peopleCount,
      reserveCoefficient: state.reserveCoefficient,
      notes: (state.notes ?? '').isEmpty ? null : state.notes,
      items: inputs,
    );

    state = state.copyWith(
      isSubmitting: true,
      clearSubmitError: true,
      fieldErrors: const {},
    );

    try {
      final plan =
          await ref.read(dishesRepositoryProvider).createProductionPlan(request);
      state = state.copyWith(isSubmitting: false, createdPlan: plan);
      return plan;
    } on DioException catch (e) {
      appLogger.w(
        'Create plan failed (HTTP ${e.response?.statusCode}): '
        '${e.response?.data}',
      );
      state = state.copyWith(
        isSubmitting: false,
        submitError: apiErrorDetails(e) ?? e.message ?? 'unknown',
        fieldErrors: _parseValidation(e),
      );
      return null;
    } catch (e) {
      appLogger.w('Create plan failed: $e');
      state = state.copyWith(isSubmitting: false, submitError: e.toString());
      return null;
    }
  }

  /// Разбирает `validation` (объект `field -> message`) из ответа 400.
  Map<String, String> _parseValidation(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['validation'] is Map) {
      final v = data['validation'] as Map;
      return {
        for (final entry in v.entries) '${entry.key}': '${entry.value}',
      };
    }
    return const {};
  }
}

final createPlanNotifierProvider =
    NotifierProvider<CreatePlanNotifier, CreatePlanState>(
  CreatePlanNotifier.new,
);

import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';

/// Черновая строка плана: блюдо + порции. Слот (категория) вычисляется из
/// блюда на этапе отправки. [key] стабилен, чтобы удаление/перестановка строк
/// не сбивали состояние полей.
class PlanDraftItem {
  const PlanDraftItem({
    required this.key,
    this.menuItemId,
    this.portions,
  });

  final int key;
  final int? menuItemId;
  final int? portions;

  bool get isFilled => menuItemId != null && (portions ?? 0) > 0;

  PlanDraftItem copyWith({int? menuItemId, int? portions}) {
    return PlanDraftItem(
      key: key,
      menuItemId: menuItemId ?? this.menuItemId,
      portions: portions ?? this.portions,
    );
  }
}

/// Состояние экрана создания плана: справочники, черновик и статус отправки.
class CreatePlanState {
  const CreatePlanState({
    this.isBootstrapping = true,
    this.bootstrapError,
    this.service = MenuServiceType.lunch,
    required this.date,
    this.kitchens = const [],
    this.kitchenId,
    this.catalog = const [],
    this.categories = const [],
    this.peopleCount,
    this.reserveCoefficient,
    this.notes,
    this.items = const [],
    this.isSubmitting = false,
    this.submitError,
    this.fieldErrors = const {},
    this.createdPlan,
  });

  final bool isBootstrapping;
  final String? bootstrapError;

  final MenuServiceType service;
  final DateTime date;

  final List<KitchenModel> kitchens;
  final int? kitchenId;

  final List<DishModel> catalog;
  final List<MenuCategoryModel> categories;

  final int? peopleCount;
  final double? reserveCoefficient;
  final String? notes;

  final List<PlanDraftItem> items;

  final bool isSubmitting;

  /// Общая ошибка отправки (например, текст из 400/500).
  final String? submitError;

  /// Ошибки валидации по полям (`field -> message`) из ответа 400.
  final Map<String, String> fieldErrors;

  /// Успешно созданный план (для показа результата).
  final ProductionPlanDetail? createdPlan;

  bool get hasMultipleKitchens => kitchens.length > 1;

  List<PlanDraftItem> get filledItems =>
      items.where((i) => i.isFilled).toList();

  /// Можно ли отправлять: выбрана кухня и есть хотя бы одна заполненная строка.
  bool get canSubmit =>
      kitchenId != null && filledItems.isNotEmpty && !isSubmitting;

  CreatePlanState copyWith({
    bool? isBootstrapping,
    String? bootstrapError,
    bool clearBootstrapError = false,
    MenuServiceType? service,
    DateTime? date,
    List<KitchenModel>? kitchens,
    int? kitchenId,
    List<DishModel>? catalog,
    List<MenuCategoryModel>? categories,
    int? peopleCount,
    bool clearPeopleCount = false,
    double? reserveCoefficient,
    bool clearReserve = false,
    String? notes,
    List<PlanDraftItem>? items,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
    Map<String, String>? fieldErrors,
    ProductionPlanDetail? createdPlan,
    bool clearCreatedPlan = false,
  }) {
    return CreatePlanState(
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      bootstrapError:
          clearBootstrapError ? null : (bootstrapError ?? this.bootstrapError),
      service: service ?? this.service,
      date: date ?? this.date,
      kitchens: kitchens ?? this.kitchens,
      kitchenId: kitchenId ?? this.kitchenId,
      catalog: catalog ?? this.catalog,
      categories: categories ?? this.categories,
      peopleCount: clearPeopleCount ? null : (peopleCount ?? this.peopleCount),
      reserveCoefficient:
          clearReserve ? null : (reserveCoefficient ?? this.reserveCoefficient),
      notes: notes ?? this.notes,
      items: items ?? this.items,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      createdPlan: clearCreatedPlan ? null : (createdPlan ?? this.createdPlan),
    );
  }
}

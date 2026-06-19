part of 'create_plan_bloc.dart';

/// Черновая строка плана: блюдо + порции. [key] стабилен для виджетов.
class PlanDraftItem extends Equatable {
  const PlanDraftItem({required this.key, this.menuItemId, this.portions});

  final int key;
  final int? menuItemId;
  final int? portions;

  bool get isFilled => menuItemId != null && (portions ?? 0) > 0;

  @override
  List<Object?> get props => [key, menuItemId, portions];
}

/// Состояние экрана создания плана: справочники, черновик и статус отправки.
class CreatePlanState extends Equatable {
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
  final String? submitError;
  final Map<String, String> fieldErrors;
  final ProductionPlanDetail? createdPlan;

  bool get hasMultipleKitchens => kitchens.length > 1;
  List<PlanDraftItem> get filledItems =>
      items.where((i) => i.isFilled).toList();
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

  @override
  List<Object?> get props => [
        isBootstrapping,
        bootstrapError,
        service,
        date,
        kitchens,
        kitchenId,
        catalog,
        categories,
        peopleCount,
        reserveCoefficient,
        notes,
        items,
        isSubmitting,
        submitError,
        fieldErrors,
        createdPlan,
      ];
}

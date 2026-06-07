import 'package:json_annotation/json_annotation.dart';

part 'production_plan_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanListResponse {
  const ProductionPlanListResponse({
    this.plans = const [],
  });

  final List<ProductionPlanListItem> plans;

  factory ProductionPlanListResponse.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanListResponseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanListItem {
  const ProductionPlanListItem({
    required this.id,
    this.serviceType,
    this.status,
    this.plannedDate,
    this.totalPortions = 0,
    this.totalCost = 0,
    this.kitchenId,
  });

  final int id;
  final String? serviceType;
  final String? status;
  final String? plannedDate;
  final int totalPortions;
  final double totalCost;
  final int? kitchenId;

  factory ProductionPlanListItem.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanListItemFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanListItemToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanDetail {
  const ProductionPlanDetail({
    required this.id,
    this.serviceType,
    this.status,
    this.plannedDate,
    this.items = const [],
  });

  final int id;
  final String? serviceType;
  final String? status;
  final String? plannedDate;
  final List<ProductionPlanItem> items;

  factory ProductionPlanDetail.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanDetailFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanDetailToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanItem {
  const ProductionPlanItem({
    required this.id,
    required this.menuItemId,
    this.plannedPortions = 0,
    this.theoreticalCost = 0,
    this.technicalCardId,
  });

  final int id;
  final int menuItemId;
  final int plannedPortions;
  final double theoreticalCost;

  /// Техкарта позиции (`technical_card_id`), если бэкенд её отдаёт.
  final int? technicalCardId;

  factory ProductionPlanItem.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanItemFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanItemToJson(this);
}

/// Тело `PATCH /chef/production-plan-items/{plan_item_id}` — меняет только
/// количество порций ячейки в недельном плане (не базовые порции техкарты).
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class UpdateProductionPlanItemRequest {
  const UpdateProductionPlanItemRequest({
    this.plannedPortions,
    this.menuItemId,
    this.slotKey,
    this.slotTitle,
    this.sortOrder,
  });

  final int? plannedPortions;

  /// Сменить блюдо ячейки (`menu_item_id`).
  final int? menuItemId;

  /// Сменить слот ячейки (`slot_key` / `slot_title` / `sort_order`).
  final String? slotKey;
  final String? slotTitle;
  final int? sortOrder;

  Map<String, dynamic> toJson() =>
      _$UpdateProductionPlanItemRequestToJson(this);
}

/// Кухня (`dto.KitchenResponse`) — нужна для создания плана.
@JsonSerializable(fieldRename: FieldRename.snake)
class KitchenModel {
  const KitchenModel({required this.id, this.name});

  final int id;
  final String? name;

  factory KitchenModel.fromJson(Map<String, dynamic> json) =>
      _$KitchenModelFromJson(json);

  Map<String, dynamic> toJson() => _$KitchenModelToJson(this);
}

/// Позиция нового плана (`dto.ProductionPlanCreateItemRequest`).
@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class ProductionPlanItemInput {
  const ProductionPlanItemInput({
    required this.menuItemId,
    required this.plannedPortions,
    this.slotKey,
    this.slotTitle,
    this.sortOrder,
  });

  final int menuItemId;
  final int plannedPortions;
  final String? slotKey;
  final String? slotTitle;
  final int? sortOrder;

  Map<String, dynamic> toJson() => _$ProductionPlanItemInputToJson(this);
}

/// Тело `POST /chef/production-plans` (`dto.ProductionPlanCreateRequest`).
@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class ProductionPlanCreateRequest {
  const ProductionPlanCreateRequest({
    required this.kitchenId,
    required this.serviceType,
    required this.plannedDate,
    required this.items,
    this.peopleCount,
    this.reserveCoefficient,
    this.notes,
  });

  final int kitchenId;
  final String serviceType;

  /// Дата в формате `YYYY-MM-DD`.
  final String plannedDate;
  final int? peopleCount;
  final double? reserveCoefficient;
  final String? notes;
  final List<ProductionPlanItemInput> items;

  Map<String, dynamic> toJson() => _$ProductionPlanCreateRequestToJson(this);
}

/// Dish row for §6.1 — из production plan на выбранную дату.
class ScheduledMenuItem {
  const ScheduledMenuItem({
    required this.menuItemId,
    required this.name,
    required this.plannedPortions,
    required this.serviceType,
    required this.planStatus,
    this.theoreticalCost,
    this.planItemId,
    this.planId,
    this.technicalCardId,
  });

  final int menuItemId;
  final String name;
  final int plannedPortions;
  final String serviceType;
  final String planStatus;
  final double? theoreticalCost;

  /// `plan_item_id` — id строки плана; нужен для PATCH planned_portions.
  final int? planItemId;

  /// `plan_id` — id плана-родителя.
  final int? planId;

  /// Техкарта позиции (`technical_card_id`), если известна.
  final int? technicalCardId;
}

import 'package:json_annotation/json_annotation.dart';

part 'production_plan_model.g.dart';

/// Лояльный парсинг чисел: бэкенд (Django `DecimalField`) иногда присылает
/// деньги/количества строкой (`"2798.0000"`), а не числом.
double _d(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? _dn(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

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

/// Ответ создания/чтения плана (`dto.ProductionPlanResponse`). Разбираем все
/// нужные поля, чтобы «что получаем» не терялось: статус, кухня, число едоков,
/// резерв, заметки и позиции со слотами/себестоимостью/наличием на складе.
@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanDetail {
  const ProductionPlanDetail({
    required this.id,
    this.serviceType,
    this.status,
    this.plannedDate,
    this.kitchenId,
    this.peopleCount,
    this.reserveCoefficient,
    this.notes,
    this.createdAt,
    this.items = const [],
  });

  final int id;
  final String? serviceType;
  final String? status;
  final String? plannedDate;
  final int? kitchenId;
  final int? peopleCount;

  @JsonKey(fromJson: _dn)
  final double? reserveCoefficient;
  final String? notes;
  final String? createdAt;
  final List<ProductionPlanItem> items;

  /// Суммарная себестоимость плана (Σ по позициям).
  double get totalCost =>
      items.fold(0, (sum, item) => sum + item.theoreticalCost);

  /// Суммарные плановые порции.
  int get totalPortions =>
      items.fold(0, (sum, item) => sum + item.plannedPortions);

  factory ProductionPlanDetail.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanDetailFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanDetailToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanItem {
  const ProductionPlanItem({
    required this.id,
    required this.menuItemId,
    this.planId,
    this.plannedPortions = 0,
    this.theoreticalCost = 0,
    this.technicalCardId,
    this.slotKey,
    this.slotTitle,
    this.sortOrder,
    this.stockAvailable,
  });

  final int id;
  final int menuItemId;
  final int? planId;
  final int plannedPortions;

  @JsonKey(fromJson: _d)
  final double theoreticalCost;

  /// Техкарта позиции (`technical_card_id`), если бэкенд её отдаёт.
  final int? technicalCardId;

  /// Слот строки меню (категория): ключ/название/порядок.
  final String? slotKey;
  final String? slotTitle;
  final int? sortOrder;

  /// Хватает ли остатков на складе под эту позицию (из ответа create/detail).
  final bool? stockAvailable;

  factory ProductionPlanItem.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanItemFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanItemToJson(this);
}

/// Результат проверки остатков (`dto.ProductionPlanStockCheckResponse`).
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ProductionPlanStockCheck {
  const ProductionPlanStockCheck({
    this.canFulfill = false,
    this.totalCost = 0,
    this.shortages = const [],
    this.warnings = const [],
  });

  final bool canFulfill;

  @JsonKey(fromJson: _d)
  final double totalCost;

  final List<ProductionPlanStockShortage> shortages;
  final List<String> warnings;

  factory ProductionPlanStockCheck.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanStockCheckFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ProductionPlanStockShortage {
  const ProductionPlanStockShortage({
    this.ingredient,
    this.ingredientId,
    this.requiredQty = 0,
    this.availableQty = 0,
    this.deficitQty = 0,
    this.unit,
  });

  final String? ingredient;
  final int? ingredientId;

  @JsonKey(fromJson: _d)
  final double requiredQty;

  @JsonKey(fromJson: _d)
  final double availableQty;

  @JsonKey(fromJson: _d)
  final double deficitQty;

  final String? unit;

  factory ProductionPlanStockShortage.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanStockShortageFromJson(json);
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

import 'package:json_annotation/json_annotation.dart';

part 'production_plan_grid_model.g.dart';

/// Ответ `GET /{role}/production-plans/grid` — готовая недельная матрица
/// «слот (категория) × день» для меню-борда.
@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanGridResponse {
  const ProductionPlanGridResponse({
    this.weekStart,
    this.weekEnd,
    this.serviceType,
    this.serviceTypeTitle,
    this.kitchenId,
    this.days = const [],
    this.rows = const [],
  });

  final String? weekStart;
  final String? weekEnd;
  final String? serviceType;
  final String? serviceTypeTitle;
  final int? kitchenId;

  /// Шапка по дням недели (Пн–Вс): люди, порции, id планов.
  final List<ProductionPlanGridDay> days;

  /// Строки сетки — слоты/категории, каждая с ячейками по дням.
  final List<ProductionPlanGridRow> rows;

  factory ProductionPlanGridResponse.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanGridResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanGridResponseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanGridDay {
  const ProductionPlanGridDay({
    this.date,
    this.weekday,
    this.weekdayTitle,
    this.planIds = const [],
    this.peopleCount = 0,
    this.totalPortions = 0,
  });

  final String? date;
  final String? weekday;
  final String? weekdayTitle;
  final List<int> planIds;
  final int peopleCount;
  final int totalPortions;

  factory ProductionPlanGridDay.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanGridDayFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanGridDayToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanGridRow {
  const ProductionPlanGridRow({
    this.slotKey,
    this.slotTitle,
    this.sortOrder = 0,
    this.cells = const [],
  });

  final String? slotKey;
  final String? slotTitle;
  final int sortOrder;
  final List<ProductionPlanGridCell> cells;

  factory ProductionPlanGridRow.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanGridRowFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanGridRowToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanGridCell {
  const ProductionPlanGridCell({
    this.date,
    this.weekday,
    this.weekdayTitle,
    this.items = const [],
  });

  final String? date;
  final String? weekday;
  final String? weekdayTitle;
  final List<ProductionPlanGridCellItem> items;

  factory ProductionPlanGridCell.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanGridCellFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanGridCellToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductionPlanGridCellItem {
  const ProductionPlanGridCellItem({
    this.categoryId,
    this.categoryName,
    this.kitchenId,
    this.menuItemId,
    this.menuItemName,
    this.planId,
    this.planItemId,
    this.plannedPortions = 0,
    this.status,
    this.stockAvailable,
    this.theoreticalCost,
    this.technicalCardId,
    this.technicalCardRootId,
    this.technicalCardVersion,
    this.technicalCardName,
    this.technicalCardBasePortions,
    this.technicalCardFoodCost,
    this.technicalCardOutputUnit,
    this.technicalCardOutputPerPortion,
    this.warnings = const [],
  });

  final int? categoryId;
  final String? categoryName;
  final int? kitchenId;
  final int? menuItemId;
  final String? menuItemName;
  final int? planId;
  final int? planItemId;
  final int plannedPortions;
  final String? status;
  final bool? stockAvailable;
  final double? theoreticalCost;

  /// Техкарта ячейки (`technical_card_id`) — версия рецепта, действующая в плане.
  final int? technicalCardId;

  /// Корневой id техкарты (`technical_card_root_id`) — общий для всех версий.
  final int? technicalCardRootId;

  /// Номер версии техкарты (`technical_card_version`).
  final int? technicalCardVersion;

  /// Название техкарты (`technical_card_name`) — обновляется после approve.
  final String? technicalCardName;

  /// Базовые порции рецепта техкарты (`technical_card_base_portions`).
  final int? technicalCardBasePortions;

  /// Себестоимость порции техкарты (`technical_card_food_cost`).
  final double? technicalCardFoodCost;

  /// Единица выхода техкарты (`technical_card_output_unit`, например `g`).
  final String? technicalCardOutputUnit;

  /// Выход на порцию (`technical_card_output_per_portion`).
  final double? technicalCardOutputPerPortion;
  final List<String> warnings;

  factory ProductionPlanGridCellItem.fromJson(Map<String, dynamic> json) =>
      _$ProductionPlanGridCellItemFromJson(json);

  Map<String, dynamic> toJson() => _$ProductionPlanGridCellItemToJson(this);
}

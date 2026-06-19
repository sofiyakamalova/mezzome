/// Недельная матрица меню-борда «слот (категория) × день»
/// (`GET /{role}/production-plans/grid`). Доменная модель — без JSON
/// (парсинг в data/dtos). Имена классов/полей сохранены, чтобы виджеты сетки
/// зависели только от domain.
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
  final List<ProductionPlanGridDay> days;
  final List<ProductionPlanGridRow> rows;
}

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
}

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
}

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
}

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
  final int? technicalCardId;
  final int? technicalCardRootId;
  final int? technicalCardVersion;
  final String? technicalCardName;
  final int? technicalCardBasePortions;
  final double? technicalCardFoodCost;
  final String? technicalCardOutputUnit;
  final double? technicalCardOutputPerPortion;
  final List<String> warnings;
}

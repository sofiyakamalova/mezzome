/// Доменная модель складского дашборда (гайд §9). Чистая: без JSON/Dio/Retrofit.
/// Парсинг живёт в data/dtos, поэтому presentation зависит только от domain.
class WarehouseDashboard {
  const WarehouseDashboard({
    required this.summary,
    required this.budgetVariance,
    required this.lowStockItems,
    required this.categoryChart,
    required this.mealCostRows,
    required this.canViewMoney,
  });

  final WarehouseSummary summary;
  final List<WarehouseBudgetVariance> budgetVariance;
  final List<WarehouseLowStockItem> lowStockItems;
  final List<WarehouseCategoryChartItem> categoryChart;
  final List<WarehouseMealCostRow> mealCostRows;
  final bool canViewMoney;
}

class WarehouseSummary {
  const WarehouseSummary({
    this.inventorySpend = 0,
    this.inventoryPurchases = 0,
    this.inventoryConsumption = 0,
    this.foodCost = 0,
    this.nonFoodSpend = 0,
    this.wasteLoss = 0,
    this.lowStockCount = 0,
    this.stockHealthPct = 0,
  });

  final double inventorySpend;
  final double inventoryPurchases;
  final double inventoryConsumption;
  final double foodCost;
  final double nonFoodSpend;
  final double wasteLoss;
  final int lowStockCount;
  final double stockHealthPct;
}

class WarehouseBudgetVariance {
  const WarehouseBudgetVariance({
    required this.category,
    this.actual = 0,
    this.target = 0,
    this.delta = 0,
    this.deviationPct = 0,
  });

  final String category;
  final double actual;
  final double target;

  /// actual - target. `> 0` = перерасход.
  final double delta;
  final double deviationPct;
}

class WarehouseLowStockItem {
  const WarehouseLowStockItem({
    required this.id,
    required this.name,
    this.unit = '',
    this.currentStock = 0,
    this.minRequired = 0,
    this.status = 'low',
  });

  final int id;
  final String name;
  final String unit;
  final double currentStock;
  final double minRequired;

  /// `low` или `critical` (остаток < 50% минимума).
  final String status;

  bool get isCritical => status == 'critical';
}

class WarehouseCategoryChartItem {
  const WarehouseCategoryChartItem({required this.category, this.value = 0});

  final String category;
  final double value;
}

/// Стоимость питания по дням. Без `meats_fish/fruits` — бэк отдаёт их фиктивно
/// (гайд §9), показываем только total/cpm/swipes.
class WarehouseMealCostRow {
  const WarehouseMealCostRow({
    this.dateLabel = '',
    this.totalCost = 0,
    this.costPerMeal = 0,
    this.swipes = 0,
  });

  final String dateLabel;
  final double totalCost;
  final double costPerMeal;
  final int swipes;
}

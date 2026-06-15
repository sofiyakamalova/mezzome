/// Складской финансовый дашборд (`GET /api/v2/dashboard/warehouse`, гайд §9):
/// закупки, потребление, остатки, low-stock, бюджет vs факт, стоимость питания.
///
/// Деньги бэкенд может присылать строкой (Decimal) — парсим лояльно.
class WarehouseDashboard {
  const WarehouseDashboard({
    required this.summary,
    required this.budgetVariance,
    required this.lowStockItems,
    required this.categoryChart,
    required this.mealCostRows,
    required this.dailySpendRows,
    required this.canViewMoney,
  });

  final WarehouseSummary summary;
  final List<WarehouseBudgetVariance> budgetVariance;
  final List<WarehouseLowStockItem> lowStockItems;
  final List<WarehouseCategoryChartItem> categoryChart;
  final List<WarehouseMealCostRow> mealCostRows;
  final List<WarehouseDailySpendRow> dailySpendRows;
  final bool canViewMoney;

  factory WarehouseDashboard.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();
    return WarehouseDashboard(
      summary: WarehouseSummary.fromJson(
        (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      budgetVariance:
          list(json['budget_variance'], WarehouseBudgetVariance.fromJson),
      lowStockItems:
          list(json['low_stock_items'], WarehouseLowStockItem.fromJson),
      categoryChart:
          list(json['category_chart'], WarehouseCategoryChartItem.fromJson),
      mealCostRows: list(json['meal_cost_rows'], WarehouseMealCostRow.fromJson),
      dailySpendRows:
          list(json['daily_spend_rows'], WarehouseDailySpendRow.fromJson),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
    );
  }
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

  /// food-закупки (НЕ COGS проданных блюд) — гайд §9.
  final double foodCost;
  final double nonFoodSpend;

  /// waste + write-offs.
  final double wasteLoss;
  final int lowStockCount;
  final double stockHealthPct;

  factory WarehouseSummary.fromJson(Map<String, dynamic> json) {
    return WarehouseSummary(
      inventorySpend: _toDouble(json['inventory_spend']),
      inventoryPurchases: _toDouble(json['inventory_purchases']),
      inventoryConsumption: _toDouble(json['inventory_consumption']),
      foodCost: _toDouble(json['food_cost']),
      nonFoodSpend: _toDouble(json['non_food_spend']),
      wasteLoss: _toDouble(json['waste_loss']),
      lowStockCount: _toInt(json['low_stock_count']),
      stockHealthPct: _toDouble(json['stock_health_pct']),
    );
  }
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

  /// actual - target. `> 0` = перерасход (гайд §15).
  final double delta;
  final double deviationPct;

  factory WarehouseBudgetVariance.fromJson(Map<String, dynamic> json) {
    return WarehouseBudgetVariance(
      category: json['category']?.toString() ?? '',
      actual: _toDouble(json['actual']),
      target: _toDouble(json['target']),
      delta: _toDouble(json['delta']),
      deviationPct: _toDouble(json['deviation_pct']),
    );
  }
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

  /// `low` или `critical` (остаток < 50% минимума) — гайд §9.
  final String status;

  bool get isCritical => status == 'critical';

  factory WarehouseLowStockItem.fromJson(Map<String, dynamic> json) {
    return WarehouseLowStockItem(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      currentStock: _toDouble(json['current_stock']),
      minRequired: _toDouble(json['min_required']),
      status: json['status']?.toString() ?? 'low',
    );
  }
}

class WarehouseCategoryChartItem {
  const WarehouseCategoryChartItem({required this.category, this.value = 0});

  final String category;
  final double value;

  factory WarehouseCategoryChartItem.fromJson(Map<String, dynamic> json) {
    return WarehouseCategoryChartItem(
      category: json['category']?.toString() ?? '',
      value: _toDouble(json['value']),
    );
  }
}

/// Стоимость питания по дням. ВНИМАНИЕ: поля `meats_fish/fruits` бэкенд сейчас
/// отдаёт фиктивно (весь total в meats_fish, 100%), поэтому их НЕ моделируем и
/// НЕ показываем — только total_cost, cost_per_meal, swipes (гайд §9).
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

  factory WarehouseMealCostRow.fromJson(Map<String, dynamic> json) {
    return WarehouseMealCostRow(
      dateLabel: json['date_label']?.toString() ?? '',
      totalCost: _toDouble(json['total_cost']),
      costPerMeal: _toDouble(json['cost_per_meal']),
      swipes: _toInt(json['swipes']),
    );
  }
}

class WarehouseDailySpendRow {
  const WarehouseDailySpendRow({
    this.dateLabel = '',
    this.food = 0,
    this.janitorials = 0,
    this.paperSupplies = 0,
    this.disposables = 0,
    this.lightEquipment = 0,
  });

  final String dateLabel;
  final double food;
  final double janitorials;
  final double paperSupplies;
  final double disposables;
  final double lightEquipment;

  factory WarehouseDailySpendRow.fromJson(Map<String, dynamic> json) {
    return WarehouseDailySpendRow(
      dateLabel: json['date_label']?.toString() ?? '',
      food: _toDouble(json['food']),
      janitorials: _toDouble(json['janitorials']),
      paperSupplies: _toDouble(json['paper_supplies']),
      disposables: _toDouble(json['disposables']),
      lightEquipment: _toDouble(json['light_equipment']),
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

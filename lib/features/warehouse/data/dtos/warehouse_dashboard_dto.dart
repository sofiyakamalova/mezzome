import 'package:mezzome/features/warehouse/domain/models/warehouse_dashboard.dart';

/// Парсинг ответа `GET /dashboard/warehouse` в доменную модель. Лоялен к
/// Decimal-строкам. Отдельный mapper не нужен — DTO строит domain-объект.
abstract final class WarehouseDashboardDto {
  static WarehouseDashboard fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();
    final summary =
        (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {};

    return WarehouseDashboard(
      summary: WarehouseSummary(
        inventorySpend: _toDouble(summary['inventory_spend']),
        inventoryPurchases: _toDouble(summary['inventory_purchases']),
        inventoryConsumption: _toDouble(summary['inventory_consumption']),
        foodCost: _toDouble(summary['food_cost']),
        nonFoodSpend: _toDouble(summary['non_food_spend']),
        wasteLoss: _toDouble(summary['waste_loss']),
        lowStockCount: _toInt(summary['low_stock_count']),
        stockHealthPct: _toDouble(summary['stock_health_pct']),
      ),
      budgetVariance: list(
        json['budget_variance'],
        (e) => WarehouseBudgetVariance(
          category: e['category']?.toString() ?? '',
          actual: _toDouble(e['actual']),
          target: _toDouble(e['target']),
          delta: _toDouble(e['delta']),
          deviationPct: _toDouble(e['deviation_pct']),
        ),
      ),
      lowStockItems: list(
        json['low_stock_items'],
        (e) => WarehouseLowStockItem(
          id: _toInt(e['id']),
          name: e['name']?.toString() ?? '',
          unit: e['unit']?.toString() ?? '',
          currentStock: _toDouble(e['current_stock']),
          minRequired: _toDouble(e['min_required']),
          status: e['status']?.toString() ?? 'low',
        ),
      ),
      categoryChart: list(
        json['category_chart'],
        (e) => WarehouseCategoryChartItem(
          category: e['category']?.toString() ?? '',
          value: _toDouble(e['value']),
        ),
      ),
      mealCostRows: list(
        json['meal_cost_rows'],
        (e) => WarehouseMealCostRow(
          dateLabel: e['date_label']?.toString() ?? '',
          totalCost: _toDouble(e['total_cost']),
          costPerMeal: _toDouble(e['cost_per_meal']),
          swipes: _toInt(e['swipes']),
        ),
      ),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
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

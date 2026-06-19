import 'package:mezzome/features/warehouse/domain/behaviors/warehouse_behavior.dart';
import 'package:mezzome/features/warehouse/domain/models/warehouse_dashboard.dart';

/// Получить складской дашборд за период. Тонкий слой: вся бизнес-логика доступа
/// в behavior; use_case — точка входа для presentation (bloc).
class GetWarehouseDashboardUseCase {
  const GetWarehouseDashboardUseCase(this._behavior);

  final WarehouseBehavior _behavior;

  Future<WarehouseDashboard?> call({
    required String period,
    required String date,
    String? mealPeriod,
  }) {
    return _behavior.getWarehouse(
      period: period,
      date: date,
      mealPeriod: mealPeriod,
    );
  }
}

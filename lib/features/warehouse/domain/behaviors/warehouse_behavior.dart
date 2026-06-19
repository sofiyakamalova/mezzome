import 'package:mezzome/features/warehouse/domain/models/warehouse_dashboard.dart';

/// Контракт доступа к складскому дашборду (domain-интерфейс). Реализуется в
/// data/services. use_case зависит от этого интерфейса, не от source/Dio.
abstract class WarehouseBehavior {
  /// Складской дашборд за период. `null` — данные недоступны (best-effort).
  Future<WarehouseDashboard?> getWarehouse({
    required String period,
    required String date,
    String? mealPeriod,
  });
}

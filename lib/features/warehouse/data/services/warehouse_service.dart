import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/warehouse/data/sources/warehouse_remote_source.dart';
import 'package:mezzome/features/warehouse/domain/behaviors/warehouse_behavior.dart';
import 'package:mezzome/features/warehouse/domain/models/warehouse_dashboard.dart';

/// Реализация [WarehouseBehavior]: обращается к source и обрабатывает ошибки.
/// best-effort — при 403/404/ошибке сети возвращает `null`, чтобы экран показал
/// «нет данных», а не падал. Без зависимостей от UI/BLoC.
class WarehouseService implements WarehouseBehavior {
  const WarehouseService(this._source);

  final WarehouseRemoteSource _source;

  @override
  Future<WarehouseDashboard?> getWarehouse({
    required String period,
    required String date,
    String? mealPeriod,
  }) async {
    try {
      return await _source.getWarehouse(
        period: period,
        date: date,
        mealPeriod: mealPeriod,
      );
    } on DioException catch (e) {
      appLogger.w('Warehouse dashboard failed: ${e.message}');
      return null;
    } catch (e) {
      appLogger.w('Warehouse dashboard failed: $e');
      return null;
    }
  }
}

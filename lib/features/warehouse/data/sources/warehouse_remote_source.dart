import 'package:dio/dio.dart';
import 'package:mezzome/features/warehouse/data/dtos/warehouse_dashboard_dto.dart';
import 'package:mezzome/features/warehouse/domain/models/warehouse_dashboard.dart';

/// Сырой доступ к API склада (HTTP через Dio). Без обработки бизнес-ошибок —
/// только запрос и разбор DTO; ошибки/исключения обрабатывает service.
class WarehouseRemoteSource {
  const WarehouseRemoteSource(this._dio);

  final Dio _dio;

  Future<WarehouseDashboard> getWarehouse({
    required String period,
    required String date,
    String? mealPeriod,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboard/warehouse',
      queryParameters: <String, dynamic>{
        'period': period,
        'date': date,
        'meal_period': ?mealPeriod,
      },
    );
    return WarehouseDashboardDto.fromJson(res.data ?? const {});
  }
}

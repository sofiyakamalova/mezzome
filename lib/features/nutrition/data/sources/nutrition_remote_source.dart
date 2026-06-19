import 'package:dio/dio.dart';
import 'package:mezzome/features/nutrition/data/dtos/nutrition_dashboard_dto.dart';
import 'package:mezzome/features/nutrition/domain/models/nutrition_dashboard.dart';

/// Сырой доступ к API питания (Dio). Эндпоинта нет в swagger, но он живой на
/// бэке (`permissions.visible_dashboards` содержит `nutrition_financial`).
class NutritionRemoteSource {
  const NutritionRemoteSource(this._dio);

  final Dio _dio;

  Future<NutritionDashboard> getNutrition({
    required String from,
    required String to,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboard/nutrition',
      queryParameters: {'from': from, 'to': to},
    );
    return NutritionDashboardDto.fromJson(res.data ?? const {});
  }
}

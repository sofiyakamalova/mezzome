import 'package:dio/dio.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/dtos/production_grid_dto.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';

/// Сырой доступ к сетке меню-борда (Dio). Роут по роли: manager → `/manager`,
/// остальные (chef) → `/chef`.
class ProductionGridRemoteSource {
  const ProductionGridRemoteSource(this._dio);

  final Dio _dio;

  Future<ProductionPlanGridResponse> getGrid({
    required UserRole role,
    required String weekStart,
    required String serviceType,
    int? kitchenId,
  }) async {
    final base = role == UserRole.manager ? '/manager' : '/chef';
    final res = await _dio.get<Map<String, dynamic>>(
      '$base/production-plans/grid',
      queryParameters: {
        'week_start': weekStart,
        'service_type': serviceType,
        'kitchen_id': ?kitchenId,
      },
    );
    return ProductionGridDto.fromJson(res.data ?? const {});
  }
}

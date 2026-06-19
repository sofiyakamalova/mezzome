import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/domain/behaviors/production_grid_behavior.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';

/// Получить недельную сетку меню-борда за неделю/приём пищи.
class GetProductionGridUseCase {
  const GetProductionGridUseCase(this._behavior);

  final ProductionGridBehavior _behavior;

  Future<ProductionPlanGridResponse> call({
    required UserRole role,
    required String weekStart,
    required String serviceType,
    int? kitchenId,
  }) {
    return _behavior.getGrid(
      role: role,
      weekStart: weekStart,
      serviceType: serviceType,
      kitchenId: kitchenId,
    );
  }
}

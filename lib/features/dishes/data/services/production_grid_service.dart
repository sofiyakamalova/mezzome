import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/sources/production_grid_remote_source.dart';
import 'package:mezzome/features/dishes/domain/behaviors/production_grid_behavior.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';

/// Реализация [ProductionGridBehavior]. Ошибки (403/сеть) пробрасываются —
/// bloc маппит их в сообщения. Role-gating тоже в bloc.
class ProductionGridService implements ProductionGridBehavior {
  const ProductionGridService(this._source);

  final ProductionGridRemoteSource _source;

  @override
  Future<ProductionPlanGridResponse> getGrid({
    required UserRole role,
    required String weekStart,
    required String serviceType,
    int? kitchenId,
  }) =>
      _source.getGrid(
        role: role,
        weekStart: weekStart,
        serviceType: serviceType,
        kitchenId: kitchenId,
      );
}

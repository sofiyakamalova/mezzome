import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';

/// Контракт загрузки недельной сетки меню-борда. Роут зависит от роли
/// (chef/manager). Бросает при ошибке — обработку (403/role) делает bloc.
abstract class ProductionGridBehavior {
  Future<ProductionPlanGridResponse> getGrid({
    required UserRole role,
    required String weekStart,
    required String serviceType,
    int? kitchenId,
  });
}

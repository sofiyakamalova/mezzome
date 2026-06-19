import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/domain/behaviors/create_plan_behavior.dart';

/// Создать производственный план.
class CreateProductionPlanUseCase {
  const CreateProductionPlanUseCase(this._behavior);

  final CreatePlanBehavior _behavior;

  Future<ProductionPlanDetail> call(
    UserRole? role,
    ProductionPlanCreateRequest request,
  ) =>
      _behavior.createPlan(role, request);
}

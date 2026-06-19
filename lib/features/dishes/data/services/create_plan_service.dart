import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/data/sources/create_plan_remote_source.dart';
import 'package:mezzome/features/dishes/domain/behaviors/create_plan_behavior.dart';

/// Реализация [CreatePlanBehavior] поверх source. Ошибки пробрасываются —
/// маппит их bloc (bootstrapError / submitError + валидация полей).
class CreatePlanService implements CreatePlanBehavior {
  const CreatePlanService(this._source);

  final CreatePlanRemoteSource _source;

  @override
  Future<List<KitchenModel>> planKitchens(UserRole? role) =>
      _source.planKitchens(role);

  @override
  Future<List<DishModel>> fetchCatalogDishes(UserRole? role) =>
      _source.fetchCatalogDishes(role);

  @override
  Future<List<MenuCategoryModel>> fetchMenuCategories() =>
      _source.fetchMenuCategories();

  @override
  Future<ProductionPlanDetail> createPlan(
    UserRole? role,
    ProductionPlanCreateRequest request,
  ) =>
      _source.createPlan(role, request);
}

import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';

/// Контракт составления плана: справочники + создание. Модели dishes пока
/// общие (data/models) — осознанное отступление на время миграции.
abstract class CreatePlanBehavior {
  Future<List<KitchenModel>> planKitchens(UserRole? role);
  Future<List<DishModel>> fetchCatalogDishes(UserRole? role);
  Future<List<MenuCategoryModel>> fetchMenuCategories();
  Future<ProductionPlanDetail> createPlan(
    UserRole? role,
    ProductionPlanCreateRequest request,
  );
}

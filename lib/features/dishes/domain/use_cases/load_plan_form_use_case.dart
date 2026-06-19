import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/domain/behaviors/create_plan_behavior.dart';

/// Справочники для формы плана (кухни, каталог блюд, категории-слоты).
class PlanFormData {
  const PlanFormData({
    required this.kitchens,
    required this.catalog,
    required this.categories,
  });

  final List<KitchenModel> kitchens;
  final List<DishModel> catalog;
  final List<MenuCategoryModel> categories;
}

/// Загружает все справочники формы параллельно.
class LoadPlanFormUseCase {
  const LoadPlanFormUseCase(this._behavior);

  final CreatePlanBehavior _behavior;

  Future<PlanFormData> call(UserRole? role) async {
    final results = await Future.wait([
      _behavior.planKitchens(role),
      _behavior.fetchCatalogDishes(role),
      _behavior.fetchMenuCategories(),
    ]);
    return PlanFormData(
      kitchens: results[0] as List<KitchenModel>,
      catalog: results[1] as List<DishModel>,
      categories: results[2] as List<MenuCategoryModel>,
    );
  }
}

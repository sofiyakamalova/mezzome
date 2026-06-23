import 'package:dio/dio.dart';
import 'package:mezzome/features/dishes/data/models/ingredient_catalog_model.dart';

/// Доступ к справочнику ингредиентов и ингредиентам блюда.
///
/// Ответы этих ручек нетипизированы в swagger (`{items, total}`), поэтому здесь
/// обычный класс поверх [Dio] (без retrofit-кодогенерации) с лояльным
/// разбором в модели [IngredientCatalogItem] / [DishIngredient].
class IngredientsApi {
  IngredientsApi(this._dio);

  final Dio _dio;

  /// Справочник ингредиентов (`GET /inventory`, `dto.InventoryListResponse`)
  /// — источник `ingredient_id` для ручного выбора в техкарте. Серверного
  /// поиска нет, фильтруем список на клиенте.
  Future<List<IngredientCatalogItem>> getInventory() async {
    final res = await _dio.get<dynamic>('/inventory');
    return ingredientItemsFromResponse(res.data)
        .map(IngredientCatalogItem.tryParse)
        .whereType<IngredientCatalogItem>()
        .toList();
  }

  /// Справочник ингредиентов конкретной кухни (`GET /kitchens/{id}/ingredients`).
  Future<List<IngredientCatalogItem>> getKitchenIngredients(
    int kitchenId,
  ) async {
    final res = await _dio.get<dynamic>('/kitchens/$kitchenId/ingredients');
    return ingredientItemsFromResponse(res.data)
        .map(IngredientCatalogItem.tryParse)
        .whereType<IngredientCatalogItem>()
        .toList();
  }

  /// Ингредиенты блюда — для автоподтяжки в техкарту с готовыми `ingredient_id`.
  Future<List<DishIngredient>> getMenuItemIngredients(int menuItemId) async {
    final res = await _dio.get<dynamic>('/menu-items/$menuItemId/ingredients');
    return ingredientItemsFromResponse(res.data)
        .map(DishIngredient.fromJson)
        .where((e) => e.name.isNotEmpty)
        .toList();
  }
}

import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/api/dishes_api.dart';
import 'package:mezzome/features/dishes/data/api/production_plans_api.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';

/// Сырой доступ к справочникам и созданию плана. Роль передаётся параметром
/// (источник — authSessionProvider на экране), ветвление chef/manager — здесь.
/// Логика повторяет тонкие методы DishesRepository, но без Riverpod Ref.
class CreatePlanRemoteSource {
  const CreatePlanRemoteSource({
    required DishesApi dishesApi,
    required ProductionPlansApi plansApi,
  })  : _dishesApi = dishesApi,
        _plansApi = plansApi;

  final DishesApi _dishesApi;
  final ProductionPlansApi _plansApi;

  /// Каталог блюд: директор — owner-ручка, иначе common.
  Future<List<DishModel>> fetchCatalogDishes(UserRole? role) async {
    if (role == null) return const [];
    final response = canOpenDirectorDashboard(role)
        ? await _dishesApi.getOwnerMenuItems()
        : await _dishesApi.getCommonMenuItems();
    return response.items;
  }

  /// Кухни для плана: manager — список `/kitchens`; chef — текущая (одна).
  Future<List<KitchenModel>> planKitchens(UserRole? role) async {
    final asManager = role != null && usesDirectorShell(role);
    if (!asManager) {
      final kitchen = await _plansApi.getChefCurrentKitchen();
      return [kitchen];
    }
    return _parseKitchens(await _plansApi.getKitchens());
  }

  /// Категории меню (источник слотов): активные, отсортированы по sort_order.
  Future<List<MenuCategoryModel>> fetchMenuCategories() async {
    final response = await _dishesApi.getCommonMenuCategories();
    return response.categories.where((c) => c.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Создание плана: manager → своя ручка, chef → chef-ручка (тело одинаково).
  Future<ProductionPlanDetail> createPlan(
    UserRole? role,
    ProductionPlanCreateRequest request,
  ) {
    final asManager = role != null && usesDirectorShell(role);
    return asManager
        ? _plansApi.createManagerPlan(request)
        : _plansApi.createChefPlan(request);
  }

  /// Лояльный разбор `GET /kitchens` (список или обёртка items/kitchens/data).
  List<KitchenModel> _parseKitchens(dynamic raw) {
    List<dynamic>? items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      final m = raw.map((k, v) => MapEntry('$k', v));
      items = (m['items'] ?? m['kitchens'] ?? m['data']) as List<dynamic>?;
    }
    if (items == null) return const [];
    return items
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .where((e) => e['id'] != null)
        .map((e) =>
            KitchenModel(id: (e['id'] as num).toInt(), name: e['name'] as String?))
        .toList();
  }
}

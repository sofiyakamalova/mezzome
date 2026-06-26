import 'package:dio/dio.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:retrofit/retrofit.dart';

part 'dishes_api.g.dart';

@RestApi()
abstract class DishesApi {
  factory DishesApi(Dio dio, {String? baseUrl}) = _DishesApi;

  /// §6.1 — список блюд (owner). На dev: GET /owner/menu/items.
  @GET('/owner/menu/items')
  Future<DishListResponse> getOwnerMenuItems();

  @GET('/common/menu/items')
  Future<DishListResponse> getCommonMenuItems();

  /// Категории меню — источник слотов при составлении плана.
  @GET('/common/menu/categories')
  Future<MenuCategoryListResponse> getCommonMenuCategories();

  /// Создание блюда меню (`POST /chef/menu/items`, `dto.MenuItemCreateRequest`)
  /// — для новой техкарты с нуля: сначала menu item, затем ТК с его id.
  /// Обязательны name/category_id/price. Ответ сырой (нет в swagger) → берём id.
  @POST('/chef/menu/items')
  Future<dynamic> createMenuItem(@Body() Map<String, dynamic> body);
}

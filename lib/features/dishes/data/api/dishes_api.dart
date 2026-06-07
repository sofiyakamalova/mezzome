import 'package:dio/dio.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
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
}

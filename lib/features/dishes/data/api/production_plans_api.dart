import 'package:dio/dio.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_grid_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:retrofit/retrofit.dart';

part 'production_plans_api.g.dart';

@RestApi()
abstract class ProductionPlansApi {
  factory ProductionPlansApi(Dio dio, {String? baseUrl}) = _ProductionPlansApi;

  /// Недельная сетка «слот × день» для меню-борда (роль chef).
  @GET('/chef/production-plans/grid')
  Future<ProductionPlanGridResponse> getChefGrid({
    @Query('week_start') String? weekStart,
    @Query('date') String? date,
    @Query('service_type') required String serviceType,
    @Query('kitchen_id') int? kitchenId,
  });

  /// Недельная сетка «слот × день» для меню-борда (роль supervisor).
  @GET('/supervisor/production-plans/grid')
  Future<ProductionPlanGridResponse> getSupervisorGrid({
    @Query('week_start') String? weekStart,
    @Query('date') String? date,
    @Query('service_type') required String serviceType,
    @Query('kitchen_id') int? kitchenId,
  });

  /// Недельная сетка «слот × день» для меню-борда (роль owner).
  @GET('/owner/production-plans/grid')
  Future<ProductionPlanGridResponse> getOwnerGrid({
    @Query('week_start') String? weekStart,
    @Query('date') String? date,
    @Query('service_type') required String serviceType,
    @Query('kitchen_id') int? kitchenId,
  });

  /// Недельная сетка «слот × день» для меню-борда (роль manager).
  @GET('/manager/production-plans/grid')
  Future<ProductionPlanGridResponse> getManagerGrid({
    @Query('week_start') String? weekStart,
    @Query('date') String? date,
    @Query('service_type') required String serviceType,
    @Query('kitchen_id') int? kitchenId,
  });

  @GET('/supervisor/production-plans')
  Future<ProductionPlanListResponse> getSupervisorPlans(
    @Query('date') String date, {
    @Query('service_type') String? serviceType,
    @Query('status') String? status,
    @Query('page_size') int? pageSize,
  });

  @GET('/supervisor/production-plans/{id}')
  Future<ProductionPlanDetail> getSupervisorPlan(@Path('id') int id);

  /// Утвердить план. Тело — `dto.ProductionPlanApproveRequest`
  /// (`{ "force": false }` достаточно).
  @POST('/supervisor/production-plans/{id}/approve')
  Future<dynamic> approveSupervisorPlan(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  /// Условно утвердить план (`dto.ProductionPlanConditionalApproveRequest`).
  @POST('/supervisor/production-plans/{id}/conditional-approve')
  Future<dynamic> conditionalApproveSupervisorPlan(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  /// Отклонить план (`{ "reason": "..." }`).
  @POST('/supervisor/production-plans/{id}/reject')
  Future<dynamic> rejectSupervisorPlan(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @GET('/chef/production-plans')
  Future<ProductionPlanListResponse> getChefPlans(
    @Query('date') String date, {
    @Query('service_type') String? serviceType,
    @Query('page_size') int? pageSize,
  });

  @GET('/chef/production-plans/{id}')
  Future<ProductionPlanDetail> getChefPlan(@Path('id') int id);

  /// Планы менеджера (`GET /manager/production-plans`). Бэкенд добавил
  /// manager-аналоги chef-ручек: список, detail и PATCH ячеек плана.
  @GET('/manager/production-plans')
  Future<ProductionPlanListResponse> getManagerPlans(
    @Query('date') String date, {
    @Query('service_type') String? serviceType,
    @Query('page_size') int? pageSize,
  });

  @GET('/manager/production-plans/{id}')
  Future<ProductionPlanDetail> getManagerPlan(@Path('id') int id);

  /// Теоретически заложенное по плану (`.../theoretical`): qty, brutto_qty,
  /// netto_qty, total_cost. Ответ нетипизирован — парсим лояльно в репозитории.
  @GET('/manager/production-plans/{id}/theoretical')
  Future<dynamic> getManagerPlanTheoretical(@Path('id') int id);

  /// Факт против плана (`.../variance-report`): theoretical_qty, actual_qty,
  /// variance_qty, variance_pct, costs. Ответ нетипизирован.
  @GET('/manager/production-plans/{id}/variance-report')
  Future<dynamic> getManagerPlanVarianceReport(
    @Path('id') int id, {
    @Query('include_loss') bool? includeLoss,
  });

  /// Правка ячейки плана менеджером
  /// (`PATCH /manager/production-plan-items/{id}`) — manager составляет план
  /// через сетку. Контракт тела тот же, что у chef-ручки.
  @PATCH('/manager/production-plan-items/{id}')
  Future<ProductionPlanItem> updateManagerProductionPlanItem(
    @Path('id') int id,
    @Body() UpdateProductionPlanItemRequest request,
  );

  /// Текущая кухня шефа — нужен `kitchen_id` для создания плана.
  @GET('/chef/kitchens/current')
  Future<KitchenModel> getChefCurrentKitchen();

  /// Список кухонь для выбора менеджером при создании плана (`GET /kitchens`).
  /// У менеджера нет одной «текущей» кухни — он выбирает из списка. Ответ
  /// нетипизирован (возможны обёртки items/kitchens/data) — парсим в репозитории.
  @GET('/kitchens')
  Future<dynamic> getKitchens();

  /// Создать производственный план (черновик). Дальше — check-stock и
  /// согласование у супервайзера.
  @POST('/chef/production-plans')
  Future<ProductionPlanDetail> createChefPlan(
    @Body() ProductionPlanCreateRequest request,
  );

  /// Создать производственный план менеджером (`POST /manager/production-plans`).
  /// Тело — тот же `ProductionPlanCreateRequest`, что и у chef-ручки.
  @POST('/manager/production-plans')
  Future<ProductionPlanDetail> createManagerPlan(
    @Body() ProductionPlanCreateRequest request,
  );

  /// Проверка остатков по плану — завершающее действие перед согласованием
  /// (`dto.ProductionPlanStockCheckResponse`).
  @POST('/chef/production-plans/{id}/check-stock')
  Future<ProductionPlanStockCheck> checkChefPlanStock(@Path('id') int id);

  /// Проверка остатков по плану менеджером
  /// (`POST /manager/production-plans/{id}/check-stock`).
  @POST('/manager/production-plans/{id}/check-stock')
  Future<ProductionPlanStockCheck> checkManagerPlanStock(@Path('id') int id);

  /// Меняет количество порций ячейки недельного плана. Это НЕ базовые порции
  /// техкарты (`base_portions`) — отдельная сущность. После правки backend
  /// сбрасывает план в `draft` (нужен повторный check-stock + approve).
  /// Если производство уже началось — вернёт `{ "error": "PLAN_NOT_EDITABLE" }`.
  @PATCH('/chef/production-plan-items/{id}')
  Future<ProductionPlanItem> updateProductionPlanItem(
    @Path('id') int id,
    @Body() UpdateProductionPlanItemRequest request,
  );
}

import 'package:dio/dio.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:retrofit/retrofit.dart';

part 'technical_cards_api.g.dart';

@RestApi()
abstract class TechnicalCardsApi {
  factory TechnicalCardsApi(Dio dio, {String? baseUrl}) = _TechnicalCardsApi;

  @GET('/chef/technical-cards')
  Future<TechnicalCardListResponse> listTechnicalCards({
    @Query('search') String? search,
    @Query('status') String? status,
    @Query('include_all_versions') bool? includeAllVersions,
  });

  @GET('/chef/technical-cards/{id}')
  Future<TechnicalCardModel> getTechnicalCard(@Path('id') int id);

  /// Список техкарт для менеджера (`GET /manager/technical-cards`). Контракт
  /// тот же, что у chef-ручки — chef-роуты менеджеру отвечают 403.
  @GET('/manager/technical-cards')
  Future<TechnicalCardListResponse> listManagerTechnicalCards({
    @Query('search') String? search,
    @Query('status') String? status,
    @Query('include_all_versions') bool? includeAllVersions,
  });

  /// Деталь техкарты для менеджера (`GET /manager/technical-cards/{id}`).
  @GET('/manager/technical-cards/{id}')
  Future<TechnicalCardModel> getManagerTechnicalCard(@Path('id') int id);

  @PATCH('/chef/technical-cards/{id}')
  Future<TechnicalCardModel> updateTechnicalCard(
    @Path('id') int id,
    @Body() UpdateTechnicalCardRequest request,
  );

  /// Правка техкарты менеджером (`PATCH /manager/technical-cards/{id}`).
  /// Контракт тела тот же, что у chef-ручки.
  @PATCH('/manager/technical-cards/{id}')
  Future<TechnicalCardModel> updateManagerTechnicalCard(
    @Path('id') int id,
    @Body() UpdateTechnicalCardRequest request,
  );

  /// Само-подтверждение техкарты шефом: одобряет черновую версию
  /// (`POST /chef/technical-cards/{id}/approve`, без тела). Шефу не нужно
  /// отправлять правку на согласование — он подтверждает её сам.
  @POST('/chef/technical-cards/{id}/approve')
  Future<TechnicalCardModel> approveTechnicalCard(@Path('id') int id);

  /// Подтверждение техкарты менеджером
  /// (`POST /manager/technical-cards/{id}/approve`, без тела).
  @POST('/manager/technical-cards/{id}/approve')
  Future<TechnicalCardModel> approveManagerTechnicalCard(@Path('id') int id);

  @GET('/chef/technical-cards/{id}/history')
  Future<dynamic> getTechnicalCardHistory(@Path('id') int id);

  /// История версий техкарты для менеджера
  /// (`GET /manager/technical-cards/{id}/history`).
  @GET('/manager/technical-cards/{id}/history')
  Future<dynamic> getManagerTechnicalCardHistory(@Path('id') int id);

  @GET('/owner/audit')
  Future<AuditLogListResponse> getOwnerAudit({
    @Query('date') String? date,
    @Query('page') int? page,
    @Query('page_size') int? pageSize,
  });
}

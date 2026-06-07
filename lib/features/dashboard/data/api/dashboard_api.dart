import 'package:dio/dio.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:retrofit/retrofit.dart';

part 'dashboard_api.g.dart';

@RestApi()
abstract class DashboardApi {
  factory DashboardApi(Dio dio, {String? baseUrl}) = _DashboardApi;

  /// Дашборд менеджера (§6.3). Деньги бэкенд скрывает по RBAC через
  /// `money_hidden` / `hidden_fields`.
  /// [period] — `day` / `week` / `month` (по умолчанию неделя на бэке).
  @GET('/manager/reports/dashboard')
  Future<ManagerDashboardModel> getManagerDashboard({
    @Query('period') String? period,
    @Query('date') String? date,
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/api_client.dart';
import 'package:mezzome/features/dashboard/data/api/dashboard_api.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';

class DashboardRepository {
  DashboardRepository(this._api);

  final DashboardApi _api;

  Future<ManagerDashboardModel> fetchManagerDashboard({
    String period = 'week',
  }) async {
    appLogger.i('Loading manager dashboard (period=$period)');
    final data = await _api.getManagerDashboard(period: period);
    appLogger.i(
      'Manager dashboard loaded: contracts=${data.activeContracts} '
      'conditionalPlans=${data.conditionalPlans} '
      'escalations=${data.openChefEscalations} '
      'moneyHidden=${data.moneyHidden}',
    );
    return data;
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dashboardApiProvider));
});

import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/dashboard/data/api/dashboard_api.dart';
import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';

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

  /// Расходы за период (`day`/`week`/`month`/`year`) на опорную дату [date]
  /// (`YYYY-MM-DD`). Только расход, без выручки.
  Future<ExpensesDashboardModel> fetchExpenses({
    required String period,
    required String date,
  }) async {
    return _api.getExpenses(period: period, date: date);
  }

  /// Вспомогательные репорты дашборда. Каждый грузится best-effort: при ошибке
  /// (403 / нет данных) возвращаем `null`, чтобы дашборд не падал целиком, а
  /// просто скрывал недоступную секцию.
  Future<T?> _tryFetch<T>(Future<T> Function() fetch, String label) async {
    try {
      return await fetch();
    } on DioException catch (e) {
      appLogger.w('Dashboard report "$label" failed: ${e.message}');
      return null;
    } catch (e) {
      appLogger.w('Dashboard report "$label" failed: $e');
      return null;
    }
  }

  Future<ManagerPlanVsFactReport?> fetchPlanVsFact() =>
      _tryFetch(_api.getPlanVsFact, 'plan-vs-fact');

  Future<ManagerCostPerHeadReport?> fetchCostPerHead() =>
      _tryFetch(_api.getCostPerHead, 'cost-per-head');

  Future<ManagerVarianceBreakdownReport?> fetchVarianceBreakdown() =>
      _tryFetch(_api.getVarianceBreakdown, 'variance-breakdown');

  Future<ManagerComplianceDigest?> fetchComplianceDigest() =>
      _tryFetch(_api.getComplianceDigest, 'compliance-digest');
}

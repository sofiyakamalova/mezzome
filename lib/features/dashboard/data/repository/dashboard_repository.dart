import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/api_client.dart';
import 'package:mezzome/features/dashboard/data/api/dashboard_api.dart';
import 'package:mezzome/features/dashboard/data/models/branch_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/financial_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';
import 'package:mezzome/features/dashboard/data/models/nutrition_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/warehouse_dashboard_model.dart';

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

  /// Главный финансовый дашборд («Обзор») за период.
  Future<FinancialDashboard> fetchFinancialDashboard({
    required String period,
    required String date,
  }) async {
    return _api.getFinancialDashboard(period: period, date: date);
  }

  /// P&L по филиалам/площадкам («объекты») за период (гайд §7).
  Future<BranchDashboard> fetchBranches({
    required String period,
    required String date,
  }) async {
    return _api.getBranches(period: period, date: date);
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

  /// «Сводная по питанию» (§20) за диапазон [from]/[to] (включительно).
  /// best-effort: при 403/404/ошибке → null (раздел покажет «недоступно»).
  Future<NutritionDashboard?> fetchNutrition({
    required String from,
    required String to,
  }) =>
      _tryFetch(() => _api.getNutrition(from: from, to: to), 'nutrition');

  /// Складской дашборд за период (гайд §9). best-effort: при ошибке → null.
  Future<WarehouseDashboard?> fetchWarehouse({
    required String period,
    required String date,
    String? mealPeriod,
  }) =>
      _tryFetch(
        () => _api.getWarehouse(
          period: period,
          date: date,
          mealPeriod: mealPeriod,
        ),
        'warehouse',
      );

  Future<ManagerPlanVsFactReport?> fetchPlanVsFact() =>
      _tryFetch(_api.getPlanVsFact, 'plan-vs-fact');

  Future<ManagerCostPerHeadReport?> fetchCostPerHead() =>
      _tryFetch(_api.getCostPerHead, 'cost-per-head');

  Future<ManagerVarianceBreakdownReport?> fetchVarianceBreakdown() =>
      _tryFetch(_api.getVarianceBreakdown, 'variance-breakdown');

  Future<ManagerComplianceDigest?> fetchComplianceDigest() =>
      _tryFetch(_api.getComplianceDigest, 'compliance-digest');
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dashboardApiProvider));
});

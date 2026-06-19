import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';
import 'package:mezzome/features/dashboard/domain/behaviors/manager_dashboard_behavior.dart';

/// Снимок менеджерского дашборда: основная сводка + доп. репорты.
class ManagerDashboardData {
  const ManagerDashboardData({
    required this.dashboard,
    this.planVsFact,
    this.costPerHead,
    this.variance,
    this.compliance,
  });

  final ManagerDashboardModel dashboard;
  final ManagerPlanVsFactReport? planVsFact;
  final ManagerCostPerHeadReport? costPerHead;
  final ManagerVarianceBreakdownReport? variance;
  final ManagerComplianceDigest? compliance;
}

/// Грузит основную сводку (обязательна) + доп. репорты параллельно (best-effort).
class LoadManagerDashboardUseCase {
  const LoadManagerDashboardUseCase(this._behavior);

  final ManagerDashboardBehavior _behavior;

  Future<ManagerDashboardData> call({required String period}) async {
    final dashboard = await _behavior.fetchDashboard(period: period);
    final results = await Future.wait([
      _behavior.fetchPlanVsFact(),
      _behavior.fetchCostPerHead(),
      _behavior.fetchVarianceBreakdown(),
      _behavior.fetchComplianceDigest(),
    ]);
    return ManagerDashboardData(
      dashboard: dashboard,
      planVsFact: results[0] as ManagerPlanVsFactReport?,
      costPerHead: results[1] as ManagerCostPerHeadReport?,
      variance: results[2] as ManagerVarianceBreakdownReport?,
      compliance: results[3] as ManagerComplianceDigest?,
    );
  }
}

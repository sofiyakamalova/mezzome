import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';

/// Контракт менеджерского дашборда (вкладка «Дашборд»): основная сводка +
/// best-effort доп. репорты (null, если роль/бэкенд их не отдаёт).
abstract class ManagerDashboardBehavior {
  Future<ManagerDashboardModel> fetchDashboard({required String period});
  Future<ManagerPlanVsFactReport?> fetchPlanVsFact();
  Future<ManagerCostPerHeadReport?> fetchCostPerHead();
  Future<ManagerVarianceBreakdownReport?> fetchVarianceBreakdown();
  Future<ManagerComplianceDigest?> fetchComplianceDigest();
}

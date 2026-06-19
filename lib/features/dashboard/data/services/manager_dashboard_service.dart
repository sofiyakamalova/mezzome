import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';
import 'package:mezzome/features/dashboard/domain/behaviors/manager_dashboard_behavior.dart';

/// Реализация [ManagerDashboardBehavior] поверх существующего DashboardRepository.
class ManagerDashboardService implements ManagerDashboardBehavior {
  const ManagerDashboardService(this._repo);

  final DashboardRepository _repo;

  @override
  Future<ManagerDashboardModel> fetchDashboard({required String period}) =>
      _repo.fetchManagerDashboard(period: period);

  @override
  Future<ManagerPlanVsFactReport?> fetchPlanVsFact() => _repo.fetchPlanVsFact();

  @override
  Future<ManagerCostPerHeadReport?> fetchCostPerHead() =>
      _repo.fetchCostPerHead();

  @override
  Future<ManagerVarianceBreakdownReport?> fetchVarianceBreakdown() =>
      _repo.fetchVarianceBreakdown();

  @override
  Future<ManagerComplianceDigest?> fetchComplianceDigest() =>
      _repo.fetchComplianceDigest();
}

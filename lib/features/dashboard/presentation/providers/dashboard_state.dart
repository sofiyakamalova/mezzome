import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';

class DashboardState {
  const DashboardState({
    this.data,
    this.period = 'week',
    this.isRefreshing = false,
    this.planVsFact,
    this.costPerHead,
    this.variance,
    this.compliance,
  });

  final ManagerDashboardModel? data;

  /// Активный период: `day` / `week` / `month`.
  final String period;
  final bool isRefreshing;

  /// Доп. репорты дашборда (best-effort, могут быть `null`, если роль/бэкенд
  /// их не отдаёт — тогда секция просто скрывается).
  final ManagerPlanVsFactReport? planVsFact;
  final ManagerCostPerHeadReport? costPerHead;
  final ManagerVarianceBreakdownReport? variance;
  final ManagerComplianceDigest? compliance;

  DashboardState copyWith({
    ManagerDashboardModel? data,
    String? period,
    bool? isRefreshing,
    ManagerPlanVsFactReport? planVsFact,
    ManagerCostPerHeadReport? costPerHead,
    ManagerVarianceBreakdownReport? variance,
    ManagerComplianceDigest? compliance,
  }) {
    return DashboardState(
      data: data ?? this.data,
      period: period ?? this.period,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      planVsFact: planVsFact ?? this.planVsFact,
      costPerHead: costPerHead ?? this.costPerHead,
      variance: variance ?? this.variance,
      compliance: compliance ?? this.compliance,
    );
  }
}

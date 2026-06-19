part of 'dashboard_bloc.dart';

enum DashboardStatus { loading, success, failure }

class DashboardState {
  const DashboardState({
    this.status = DashboardStatus.loading,
    this.period = 'week',
    this.isRefreshing = false,
    this.data,
    this.planVsFact,
    this.costPerHead,
    this.variance,
    this.compliance,
    this.error,
  });

  final DashboardStatus status;

  /// Активный период: `day` / `week` / `month`.
  final String period;
  final bool isRefreshing;

  final ManagerDashboardModel? data;

  /// Доп. репорты (best-effort, могут быть `null` — секция скрывается).
  final ManagerPlanVsFactReport? planVsFact;
  final ManagerCostPerHeadReport? costPerHead;
  final ManagerVarianceBreakdownReport? variance;
  final ManagerComplianceDigest? compliance;

  /// Ошибка основной загрузки (для экрана ошибки).
  final Object? error;

  DashboardState copyWith({
    DashboardStatus? status,
    String? period,
    bool? isRefreshing,
    ManagerDashboardModel? data,
    ManagerPlanVsFactReport? planVsFact,
    ManagerCostPerHeadReport? costPerHead,
    ManagerVarianceBreakdownReport? variance,
    ManagerComplianceDigest? compliance,
    Object? error,
  }) {
    return DashboardState(
      status: status ?? this.status,
      period: period ?? this.period,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      data: data ?? this.data,
      planVsFact: planVsFact ?? this.planVsFact,
      costPerHead: costPerHead ?? this.costPerHead,
      variance: variance ?? this.variance,
      compliance: compliance ?? this.compliance,
      error: error ?? this.error,
    );
  }
}

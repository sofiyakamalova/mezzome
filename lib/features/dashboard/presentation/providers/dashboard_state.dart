import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';

class DashboardState {
  const DashboardState({
    this.data,
    this.period = 'week',
    this.isRefreshing = false,
  });

  final ManagerDashboardModel? data;

  /// Активный период: `day` / `week` / `month`.
  final String period;
  final bool isRefreshing;

  DashboardState copyWith({
    ManagerDashboardModel? data,
    String? period,
    bool? isRefreshing,
  }) {
    return DashboardState(
      data: data ?? this.data,
      period: period ?? this.period,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

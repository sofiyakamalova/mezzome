part of 'dashboard_bloc.dart';

sealed class DashboardEvent {
  const DashboardEvent();
}

class DashboardRequested extends DashboardEvent {
  const DashboardRequested();
}

class DashboardRefreshed extends DashboardEvent {
  const DashboardRefreshed();
}

class DashboardPeriodChanged extends DashboardEvent {
  const DashboardPeriodChanged(this.period);

  final String period;
}

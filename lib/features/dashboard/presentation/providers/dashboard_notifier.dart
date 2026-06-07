import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';
import 'package:mezzome/features/dashboard/presentation/providers/dashboard_state.dart';

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  String _period = 'week';

  @override
  Future<DashboardState> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = AsyncData(
      (state.valueOrNull ?? const DashboardState()).copyWith(isRefreshing: true),
    );
    state = await AsyncValue.guard(_load);
  }

  /// Сменить период (`day` / `week` / `month`) и перезагрузить.
  /// Прежние данные остаются видимыми с флагом [DashboardState.isRefreshing],
  /// чтобы переключатель периода не схлопывался в спиннер.
  Future<void> setPeriod(String period) async {
    if (period == _period) {
      return;
    }
    _period = period;
    state = AsyncData(
      (state.valueOrNull ?? const DashboardState())
          .copyWith(period: period, isRefreshing: true),
    );
    state = await AsyncValue.guard(_load);
  }

  Future<DashboardState> _load() async {
    final data = await ref
        .read(dashboardRepositoryProvider)
        .fetchManagerDashboard(period: _period);
    return DashboardState(data: data, period: _period);
  }
}

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

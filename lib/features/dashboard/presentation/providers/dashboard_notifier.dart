import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';
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
    final repo = ref.read(dashboardRepositoryProvider);
    // Основной дашборд обязателен (его ошибка = ошибка экрана). Доп. репорты —
    // best-effort, грузятся параллельно; недоступные просто не показываем.
    final data = await repo.fetchManagerDashboard(period: _period);
    final results = await Future.wait([
      repo.fetchPlanVsFact(),
      repo.fetchCostPerHead(),
      repo.fetchVarianceBreakdown(),
      repo.fetchComplianceDigest(),
    ]);
    return DashboardState(
      data: data,
      period: _period,
      planVsFact: results[0] as ManagerPlanVsFactReport?,
      costPerHead: results[1] as ManagerCostPerHeadReport?,
      variance: results[2] as ManagerVarianceBreakdownReport?,
      compliance: results[3] as ManagerComplianceDigest?,
    );
  }
}

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

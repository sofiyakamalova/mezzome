import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dashboard/data/models/financial_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';

/// Главный финансовый дашборд («Обзор»). Период day/week/month/year; данные
/// держим при смене периода (copyWithPrevious), чтобы вкладки не «моргали».
class FinancialDashboardNotifier extends AsyncNotifier<FinancialDashboard> {
  String _period = 'week';
  late final String _date = DateFormatUtil.apiDate(DateFormatUtil.today);

  String get period => _period;

  @override
  Future<FinancialDashboard> build() => _load();

  Future<FinancialDashboard> _load() => ref
      .read(dashboardRepositoryProvider)
      .fetchFinancialDashboard(period: _period, date: _date);

  Future<void> refresh() async {
    state = const AsyncLoading<FinancialDashboard>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<void> setPeriod(String period) async {
    if (period == _period) {
      return;
    }
    _period = period;
    state = const AsyncLoading<FinancialDashboard>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final financialDashboardNotifierProvider =
    AsyncNotifierProvider<FinancialDashboardNotifier, FinancialDashboard>(
  FinancialDashboardNotifier.new,
);

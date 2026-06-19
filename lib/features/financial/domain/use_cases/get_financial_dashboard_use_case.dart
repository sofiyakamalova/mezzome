import 'package:mezzome/features/financial/domain/behaviors/financial_behavior.dart';
import 'package:mezzome/features/financial/domain/models/financial_dashboard.dart';

/// Получить «Обзор» (P&L) за период.
class GetFinancialDashboardUseCase {
  const GetFinancialDashboardUseCase(this._behavior);

  final FinancialBehavior _behavior;

  Future<FinancialDashboard> call({
    required String period,
    required String date,
  }) {
    return _behavior.getFinancial(period: period, date: date);
  }
}

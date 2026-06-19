import 'package:mezzome/features/financial/domain/models/financial_dashboard.dart';

/// Контракт доступа к главному финансовому дашборду («Обзор»).
abstract class FinancialBehavior {
  Future<FinancialDashboard> getFinancial({
    required String period,
    required String date,
  });
}

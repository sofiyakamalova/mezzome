import 'package:mezzome/features/branches/domain/models/branch_dashboard.dart';
import 'package:mezzome/features/branches/domain/models/expenses_breakdown.dart';

/// Контракт доступа к данным «Объектов»: P&L по филиалам и расходы по категориям.
/// Реализуется в data/services. `null` — данные недоступны (best-effort).
abstract class BranchesBehavior {
  Future<BranchDashboard?> getBranches({
    required String period,
    required String date,
  });

  Future<ExpensesBreakdown?> getExpenses({
    required String period,
    required String date,
  });
}

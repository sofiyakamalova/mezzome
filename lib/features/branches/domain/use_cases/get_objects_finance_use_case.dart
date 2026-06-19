import 'package:mezzome/features/branches/domain/behaviors/branches_behavior.dart';
import 'package:mezzome/features/branches/domain/models/branch_dashboard.dart';
import 'package:mezzome/features/branches/domain/models/expenses_breakdown.dart';
import 'package:mezzome/features/branches/domain/models/object_finance.dart';

/// Собирает карточки P&L по объектам: тянет branches + expenses и склеивает по
/// `branchId`. Это бизнес-логика → живёт в use_case, не в bloc и не в data.
class GetObjectsFinanceUseCase {
  const GetObjectsFinanceUseCase(this._behavior);

  final BranchesBehavior _behavior;

  /// `null`, если P&L по филиалам недоступен (provider вернул null).
  Future<ObjectsFinance?> call({
    required String period,
    required String date,
  }) async {
    final results = await Future.wait([
      _behavior.getBranches(period: period, date: date),
      _behavior.getExpenses(period: period, date: date),
    ]);
    final branches = results[0] as BranchDashboard?;
    if (branches == null) return null;
    final expenses = (results[1] as ExpensesBreakdown?) ?? ExpensesBreakdown.empty;
    return _merge(branches, expenses);
  }

  ObjectsFinance _merge(BranchDashboard branches, ExpensesBreakdown expenses) {
    final objects = <ObjectFinance>[];

    // Агрегат «All»: полную разбивку берём из верхнеуровневого by_category
    // (включает нераспределённые, напр. зарплату); сумма = opex_total.
    // unallocatedOpex показываем справочной строкой «в т.ч.».
    final t = branches.totals;
    final allExpenses = Map<String, double>.from(expenses.byCategory);
    final allExpensesTotal = t.opexTotal ?? expenses.total;
    objects.add(
      ObjectFinance(
        id: ObjectFinance.allId,
        name: '',
        revenue: t.revenue,
        cogs: t.cost,
        grossProfit: t.grossProfit,
        grossMarginPct: t.grossMarginPct,
        expensesByCategory: allExpenses,
        expensesTotal: allExpensesTotal,
        netProfit: t.netProfit ?? (t.revenue - t.cost - allExpensesTotal),
        ordersCount: branches.branches.fold(0, (s, b) => s + b.ordersCount),
        unallocatedOpex: t.unallocatedOpex,
      ),
    );

    for (final b in branches.branches) {
      final exp = expenses.byBranch[b.id];
      final byCategory = exp?.byCategory ?? const <String, double>{};
      final expensesTotal = b.opexTotal ?? exp?.total ?? 0;
      objects.add(
        ObjectFinance(
          id: b.id,
          name: b.name.isNotEmpty ? b.name : b.shortLabel,
          revenue: b.revenue,
          cogs: b.cost,
          grossProfit: b.grossProfit,
          grossMarginPct: b.grossMarginPct,
          expensesByCategory: byCategory,
          expensesTotal: expensesTotal,
          netProfit: b.netProfit ?? (b.revenue - b.cost - expensesTotal),
          ordersCount: b.ordersCount,
        ),
      );
    }

    return ObjectsFinance(
      objects: objects,
      canViewMoney: branches.canViewMoney,
    );
  }
}

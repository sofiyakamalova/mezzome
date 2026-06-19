/// Расходы по категориям и филиалам (гайд §8). Доменная модель для склейки
/// карточек объектов: верхнеуровневый разрез + по каждому филиалу.
class ExpensesBreakdown {
  const ExpensesBreakdown({
    this.byCategory = const {},
    this.total = 0,
    this.byBranch = const {},
  });

  /// Категория → сумма (по всей сети). Для агрегата «All».
  final Map<String, double> byCategory;
  final double total;

  /// branchId → расходы филиала.
  final Map<int, BranchExpense> byBranch;

  static const empty = ExpensesBreakdown();
}

class BranchExpense {
  const BranchExpense({this.byCategory = const {}, this.total = 0});

  final Map<String, double> byCategory;
  final double total;
}

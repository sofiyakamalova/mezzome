/// Карточка P&L одного объекта (филиала) — результат склейки `branches` и
/// `expenses` (гайд §7+§8). `isAll` — агрегат «Все».
class ObjectFinance {
  const ObjectFinance({
    required this.id,
    required this.name,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.expensesByCategory,
    required this.expensesTotal,
    required this.netProfit,
    required this.ordersCount,
    this.unallocatedOpex,
  });

  final int id;
  final String name;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double grossMarginPct;

  /// Построчная расшифровка расходов: `category -> amount` (ЗП, электричество…).
  final Map<String, double> expensesByCategory;
  final double expensesTotal;
  final double netProfit;
  final int ordersCount;

  /// Только для агрегата «All»: нераспределённый OPEX (справочная строка).
  final double? unallocatedOpex;

  bool get isAll => id == allId;
  static const int allId = -1;
}

/// Результат склейки: список карточек (первая — агрегат «All») + право на деньги.
class ObjectsFinance {
  const ObjectsFinance({required this.objects, required this.canViewMoney});

  final List<ObjectFinance> objects;
  final bool canViewMoney;

  List<int> get branchIds =>
      objects.where((o) => !o.isAll).map((o) => o.id).toList();
}

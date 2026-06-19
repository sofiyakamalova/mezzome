/// Доменные модели P&L по филиалам (гайд §7). Чистые, без JSON. Питают только
/// склейку в use_case; UI работает с [ObjectFinance].
class BranchDashboard {
  const BranchDashboard({
    required this.branches,
    required this.totals,
    required this.canViewMoney,
  });

  final List<BranchRow> branches;
  final BranchTotals totals;
  final bool canViewMoney;
}

class BranchRow {
  const BranchRow({
    required this.id,
    required this.name,
    this.shortLabel = '',
    this.revenue = 0,
    this.cost = 0,
    this.grossProfit = 0,
    this.grossMarginPct = 0,
    this.opexTotal,
    this.netProfit,
    this.ordersCount = 0,
  });

  final int id;
  final String name;
  final String shortLabel;
  final double revenue;
  final double cost;
  final double grossProfit;
  final double grossMarginPct;
  final double? opexTotal;
  final double? netProfit;
  final int ordersCount;
}

class BranchTotals {
  const BranchTotals({
    this.revenue = 0,
    this.cost = 0,
    this.grossProfit = 0,
    this.grossMarginPct = 0,
    this.unallocatedOpex = 0,
    this.opexTotal,
    this.netProfit,
  });

  final double revenue;
  final double cost;
  final double grossProfit;
  final double grossMarginPct;
  final double unallocatedOpex;
  final double? opexTotal;
  final double? netProfit;
}

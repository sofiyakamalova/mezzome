/// Дашборд P&L по филиалам/площадкам (объекты «Catering 1/2/3»):
/// `GET /api/v2/dashboard/branches?period=&date=` (гайд §7).
///
/// Деньги бэкенд может присылать строкой (Decimal) — парсим лояльно.
/// `opex_total` и `net_profit` nullable: по строке филиала они могут
/// отсутствовать, если OPEX не распределён (см. `totals.unallocated_opex`).
class BranchDashboard {
  const BranchDashboard({
    required this.period,
    required this.date,
    required this.branches,
    required this.totals,
    required this.canViewMoney,
  });

  final String period;
  final String date;
  final List<BranchRow> branches;
  final BranchTotals totals;
  final bool canViewMoney;

  factory BranchDashboard.fromJson(Map<String, dynamic> json) {
    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();
    final rawBranches = json['branches'];
    final branches = rawBranches is List
        ? rawBranches
              .whereType<Map>()
              .map((e) => BranchRow.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const <BranchRow>[];

    return BranchDashboard(
      period: json['period']?.toString() ?? 'week',
      date: json['date']?.toString() ?? '',
      branches: branches,
      totals: BranchTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
    );
  }
}

class BranchRow {
  const BranchRow({
    required this.id,
    required this.name,
    required this.shortLabel,
    this.grossSales = 0,
    this.discountsTotal = 0,
    this.serviceChargeTotal = 0,
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
  final double grossSales;
  final double discountsTotal;
  final double serviceChargeTotal;
  final double revenue;
  final double cost;
  final double grossProfit;
  final double grossMarginPct;

  /// Расходы (OPEX) филиала. `null`, если бэкенд не вернул значение.
  final double? opexTotal;

  /// Чистая прибыль филиала (без глобального OPEX). `null`, если не вернулось.
  final double? netProfit;
  final int ordersCount;

  factory BranchRow.fromJson(Map<String, dynamic> json) {
    return BranchRow(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      shortLabel: json['short_label']?.toString() ?? '',
      grossSales: _toDouble(json['gross_sales']),
      discountsTotal: _toDouble(json['discounts_total']),
      serviceChargeTotal: _toDouble(json['service_charge_total']),
      revenue: _toDouble(json['revenue']),
      cost: _toDouble(json['cost']),
      grossProfit: _toDouble(json['gross_profit']),
      grossMarginPct: _toDouble(json['gross_margin_pct']),
      opexTotal: _toDoubleOrNull(json['opex_total']),
      netProfit: _toDoubleOrNull(json['net_profit']),
      ordersCount: _toInt(json['orders_count']),
    );
  }
}

class BranchTotals {
  const BranchTotals({
    this.grossSales = 0,
    this.discountsTotal = 0,
    this.serviceChargeTotal = 0,
    this.revenue = 0,
    this.cost = 0,
    this.grossProfit = 0,
    this.grossMarginPct = 0,
    this.unallocatedOpex = 0,
    this.opexTotal,
    this.netProfit,
  });

  final double grossSales;
  final double discountsTotal;
  final double serviceChargeTotal;
  final double revenue;
  final double cost;
  final double grossProfit;
  final double grossMarginPct;

  /// Нераспределённый OPEX (расходы без привязки к филиалу). Показывать
  /// отдельной строкой, иначе сумма карточек ≠ общему итогу (гайд §7).
  final double unallocatedOpex;
  final double? opexTotal;
  final double? netProfit;

  factory BranchTotals.fromJson(Map<String, dynamic> json) {
    return BranchTotals(
      grossSales: _toDouble(json['gross_sales']),
      discountsTotal: _toDouble(json['discounts_total']),
      serviceChargeTotal: _toDouble(json['service_charge_total']),
      revenue: _toDouble(json['revenue']),
      cost: _toDouble(json['cost']),
      grossProfit: _toDouble(json['gross_profit']),
      grossMarginPct: _toDouble(json['gross_margin_pct']),
      unallocatedOpex: _toDouble(json['unallocated_opex']),
      opexTotal: _toDoubleOrNull(json['opex_total']),
      netProfit: _toDoubleOrNull(json['net_profit']),
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _toDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

import 'package:mezzome/features/branches/domain/models/branch_dashboard.dart';

/// Парсинг `GET /dashboard/branches` → доменную модель. `opex_total`/`net_profit`
/// nullable (гайд §7). Лоялен к Decimal-строкам.
abstract final class BranchDashboardDto {
  static BranchDashboard fromJson(Map<String, dynamic> json) {
    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();
    final rawBranches = json['branches'];
    final branches = rawBranches is List
        ? rawBranches
              .whereType<Map>()
              .map((e) => _row(e.cast<String, dynamic>()))
              .toList()
        : const <BranchRow>[];

    return BranchDashboard(
      branches: branches,
      totals: _totals(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
    );
  }

  static BranchRow _row(Map<String, dynamic> e) => BranchRow(
        id: _toInt(e['id']),
        name: e['name']?.toString() ?? '',
        shortLabel: e['short_label']?.toString() ?? '',
        revenue: _toDouble(e['revenue']),
        cost: _toDouble(e['cost']),
        grossProfit: _toDouble(e['gross_profit']),
        grossMarginPct: _toDouble(e['gross_margin_pct']),
        opexTotal: _toDoubleOrNull(e['opex_total']),
        netProfit: _toDoubleOrNull(e['net_profit']),
        ordersCount: _toInt(e['orders_count']),
      );

  static BranchTotals _totals(Map<String, dynamic> j) => BranchTotals(
        revenue: _toDouble(j['revenue']),
        cost: _toDouble(j['cost']),
        grossProfit: _toDouble(j['gross_profit']),
        grossMarginPct: _toDouble(j['gross_margin_pct']),
        unallocatedOpex: _toDouble(j['unallocated_opex']),
        opexTotal: _toDoubleOrNull(j['opex_total']),
        netProfit: _toDoubleOrNull(j['net_profit']),
      );
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? _toDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

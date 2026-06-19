import 'package:mezzome/features/branches/domain/models/expenses_breakdown.dart';

/// Парсинг `GET /dashboard/expenses` → доменную модель (категории + by_branch).
abstract final class ExpensesBreakdownDto {
  static ExpensesBreakdown fromJson(Map<String, dynamic> json) {
    final byBranch = <int, BranchExpense>{};
    final raw = json['by_branch'];
    if (raw is List) {
      for (final e in raw.whereType<Map>()) {
        final m = e.cast<String, dynamic>();
        byBranch[_toInt(m['branch_id'])] = BranchExpense(
          byCategory: _categoryMap(m['by_category']),
          total: _toDouble(m['total']),
        );
      }
    }
    return ExpensesBreakdown(
      byCategory: _categoryMap(json['by_category']),
      total: _toDouble(json['total']),
      byBranch: byBranch,
    );
  }
}

Map<String, double> _categoryMap(Object? raw) {
  final map = <String, double>{};
  if (raw is Map) {
    raw.forEach((k, v) => map[k.toString()] = _toDouble(v));
  }
  return map;
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

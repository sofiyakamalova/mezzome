/// Модель отчёта «план vs факт» по производственному плану
/// (`GET /manager/production-plans/{id}/variance-report`).
///
/// Ответ ручки в swagger нетипизирован (`{}`), поля известны из описания
/// бэкендера (`theoretical_qty, actual_qty, variance_qty, variance_pct, costs`
/// + `qty/brutto_qty/netto_qty/total_cost`). Парсим максимально лояльно:
/// допускаем разные имена ключей, итоги либо на верхнем уровне, либо в
/// `totals`/`costs`, а строки — в `items`/`ingredients`/`lines`/`rows` либо
/// в самом массиве. На реальном ответе маппинг уточним.
library;

double _num(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v);
      if (p != null) return p;
    }
  }
  return 0;
}

double? _numOrNull(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v);
      if (p != null) return p;
    }
  }
  return null;
}

String? _str(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    final s = v?.toString().trim();
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : const {};

/// Строка отчёта по одному ингредиенту: заложено vs факт.
class PlanVarianceLine {
  const PlanVarianceLine({
    required this.name,
    this.unit,
    this.theoreticalQty = 0,
    this.actualQty = 0,
    this.varianceQty = 0,
    this.variancePct,
  });

  final String name;
  final String? unit;

  /// Сколько заложено (план).
  final double theoreticalQty;

  /// Сколько фактически забрали.
  final double actualQty;

  /// Отклонение в количестве (факт − план).
  final double varianceQty;

  /// Отклонение в процентах.
  final double? variancePct;

  factory PlanVarianceLine.fromJson(Map<String, dynamic> m) {
    return PlanVarianceLine(
      name: _str(m, ['ingredient', 'name', 'ingredient_name', 'title']) ?? '—',
      unit: _str(m, ['unit', 'unit_name']),
      theoreticalQty: _num(m, [
        'theoretical_qty',
        'theoretical',
        'planned_qty',
        'plan_qty',
        'netto_qty',
        'qty',
      ]),
      actualQty: _num(m, ['actual_qty', 'actual', 'fact_qty', 'fact']),
      varianceQty: _num(m, ['variance_qty', 'variance', 'delta_qty', 'delta']),
      variancePct:
          _numOrNull(m, ['variance_pct', 'variance_percent', 'delta_pct']),
    );
  }
}

class PlanVarianceReport {
  const PlanVarianceReport({
    this.planId,
    this.theoreticalCost = 0,
    this.actualCost = 0,
    this.varianceCost = 0,
    this.variancePct,
    this.lines = const [],
  });

  final int? planId;
  final double theoreticalCost;
  final double actualCost;
  final double varianceCost;
  final double? variancePct;
  final List<PlanVarianceLine> lines;

  bool get isEmpty =>
      lines.isEmpty &&
      theoreticalCost == 0 &&
      actualCost == 0 &&
      varianceCost == 0;

  factory PlanVarianceReport.fromJson(dynamic data, {int? planId}) {
    final root = _asMap(data);

    // Строки — из первого подходящего массива.
    dynamic rawLines;
    for (final k in ['items', 'ingredients', 'lines', 'rows', 'variances']) {
      if (root[k] is List) {
        rawLines = root[k];
        break;
      }
    }
    rawLines ??= data is List ? data : const [];
    final lines = (rawLines as List)
        .whereType<Map>()
        .map((e) => PlanVarianceLine.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();

    // Итоги по стоимости — на верхнем уровне, либо в totals/costs
    // (приоритет вложенным: costs → totals → root).
    final merged = {
      ...root,
      ..._asMap(root['totals']),
      ..._asMap(root['costs']),
    };
    final theoreticalCost = _num(merged, [
      'total_theoretical_cost',
      'theoretical_cost',
      'theoretical',
      'planned_cost',
      'plan_cost',
      'total_cost',
    ]);
    final varianceCost = _num(merged, [
      'total_variance_cost',
      'variance_cost',
      'cost_variance',
      'delta_cost',
    ]);
    // У variance-report в totals нет процента — считаем сами от заложенного.
    final variancePct = _numOrNull(merged, ['variance_pct', 'variance_percent']) ??
        (theoreticalCost != 0 ? varianceCost / theoreticalCost * 100 : null);
    return PlanVarianceReport(
      planId: planId,
      theoreticalCost: theoreticalCost,
      actualCost: _num(
          merged, ['total_actual_cost', 'actual_cost', 'actual', 'fact_cost']),
      varianceCost: varianceCost,
      variancePct: variancePct,
      lines: lines,
    );
  }
}

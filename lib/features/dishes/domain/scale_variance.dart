/// Факт по весам vs план (P2.10) — разбор ответа
/// `GET /variance/technical-cards/{id}/breakdown`.
///
/// Форма ответа в swagger не зафиксирована (свободный объект), поэтому парсим
/// лояльно: ищем массив строк по нескольким возможным ключам и в каждой строке
/// достаём «теоретическое» (план/заявлено) и «фактическое» (факт по весам)
/// количество по набору синонимов. Если ничего не нашли — [hasData] = false и
/// UI показывает заглушку.
class ScaleVarianceLine {
  const ScaleVarianceLine({
    required this.name,
    this.theoreticalQty,
    this.actualQty,
    this.unit,
    this.variancePct,
  });

  final String name;
  final double? theoreticalQty;
  final double? actualQty;
  final String? unit;
  final double? variancePct;
}

class ScaleVarianceResult {
  const ScaleVarianceResult({this.lines = const []});

  final List<ScaleVarianceLine> lines;

  bool get hasData => lines.isNotEmpty;

  double get declaredTotal =>
      lines.fold(0, (s, l) => s + (l.theoreticalQty ?? 0));
  double get actualTotal => lines.fold(0, (s, l) => s + (l.actualQty ?? 0));

  /// Единица из первой строки с заполненным `unit` (для подписи итогов).
  String? get unit {
    for (final l in lines) {
      if (l.unit != null && l.unit!.isNotEmpty) return l.unit;
    }
    return null;
  }
}

double? _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

double? _pickNum(Map<String, dynamic> m, List<String> keys) {
  for (final e in m.entries) {
    final k = e.key.toLowerCase();
    if (keys.any(k.contains)) {
      final n = _num(e.value);
      if (n != null) return n;
    }
  }
  return null;
}

String? _pickStr(Map<String, dynamic> m, List<String> keys) {
  for (final e in m.entries) {
    final k = e.key.toLowerCase();
    if (keys.any(k.contains) && e.value is String && e.value != '') {
      return e.value as String;
    }
  }
  return null;
}

ScaleVarianceResult parseScaleVariance(Object? raw) {
  List<dynamic>? items;
  if (raw is List) {
    items = raw;
  } else if (raw is Map) {
    final map = raw.map((k, v) => MapEntry('$k', v));
    for (final key in const [
      'items',
      'lines',
      'ingredients',
      'breakdown',
      'rows',
    ]) {
      final v = map[key];
      if (v is List) {
        items = v;
        break;
      }
    }
  }
  if (items == null) {
    return const ScaleVarianceResult();
  }

  final lines = <ScaleVarianceLine>[];
  for (final item in items) {
    if (item is! Map) continue;
    final m = item.map((k, v) => MapEntry('$k', v));
    final theo = _pickNum(m, const [
      'theoretical_qty',
      'theoretical',
      'declared',
      'planned',
      'plan_qty',
      'expected',
    ]);
    final actual = _pickNum(m, const [
      'actual_qty',
      'actual',
      'fact',
      'weighed',
      'measured',
    ]);
    if (theo == null && actual == null) continue;
    lines.add(
      ScaleVarianceLine(
        name: _pickStr(m, const [
              'ingredient_name',
              'ingredient',
              'name',
              'category',
            ]) ??
            '—',
        theoreticalQty: theo,
        actualQty: actual,
        unit: _pickStr(m, const ['unit']),
        variancePct: _pickNum(m, const [
          'variance_pct',
          'deviation_pct',
          'variance',
        ]),
      ),
    );
  }
  return ScaleVarianceResult(lines: lines);
}

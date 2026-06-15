/// «Сводная по питанию» (`GET /api/v2/dashboard/nutrition?from=&to=`, гайд §20):
/// затраты по приёмам пищи, состав (food_group), стоимость на человека (СРМ),
/// статус норма/внимание/дисбаланс, прогноз на месяц, инсайты Inspector/Analyst.
///
/// Деньги могут приходить строкой (Decimal) — парсим лояльно.
class NutritionDashboard {
  const NutritionDashboard({
    required this.from,
    required this.to,
    required this.summary,
    required this.mealPeriods,
    required this.daily,
    required this.composition,
    required this.insights,
    required this.canViewMoney,
    this.forecast,
  });

  final String from;
  final String to;
  final NutritionSummary summary;
  final List<NutritionMealPeriod> mealPeriods;
  final List<NutritionDay> daily;
  final List<NutritionComposition> composition;
  final List<NutritionInsight> insights;
  final NutritionForecast? forecast;
  final bool canViewMoney;

  /// Приём пищи по коду (`BREAKFAST`/`LUNCH`/`DINNER`), null если нет.
  NutritionMealPeriod? mealByCode(String code) {
    for (final m in mealPeriods) {
      if (m.code.toUpperCase() == code.toUpperCase()) return m;
    }
    return null;
  }

  factory NutritionDashboard.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();
    final forecastRaw = (json['forecast'] as Map?)?.cast<String, dynamic>();
    return NutritionDashboard(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      summary: NutritionSummary.fromJson(
        (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      mealPeriods: list(json['meal_periods'], NutritionMealPeriod.fromJson),
      daily: list(json['daily'], NutritionDay.fromJson),
      composition: list(json['composition'], NutritionComposition.fromJson),
      insights: list(json['insights'], NutritionInsight.fromJson),
      forecast:
          forecastRaw == null ? null : NutritionForecast.fromJson(forecastRaw),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
    );
  }
}

class NutritionSummary {
  const NutritionSummary({
    this.totalCost = 0,
    this.changePct = 0,
    this.mealsServed = 0,
    this.averageCostPerMeal = 0,
    this.costPerMealChangePct = 0,
    this.status = 'normal',
  });

  final double totalCost;
  final double changePct;
  final int mealsServed;
  final double averageCostPerMeal;
  final double costPerMealChangePct;
  final String status;

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    return NutritionSummary(
      totalCost: _toDouble(json['total_cost']),
      changePct: _toDouble(json['change_pct']),
      mealsServed: _toInt(json['meals_served']),
      averageCostPerMeal: _toDouble(json['average_cost_per_meal']),
      costPerMealChangePct: _toDouble(json['cost_per_meal_change_pct']),
      status: json['status']?.toString() ?? 'normal',
    );
  }
}

class NutritionMealPeriod {
  const NutritionMealPeriod({
    required this.code,
    this.name = '',
    this.totalCost = 0,
    this.changePct = 0,
    this.mealsServed = 0,
    this.averageCostPerMeal = 0,
    this.sharePct = 0,
    this.status = 'normal',
  });

  final String code;
  final String name;
  final double totalCost;
  final double changePct;
  final int mealsServed;
  final double averageCostPerMeal;
  final double sharePct;
  final String status;

  factory NutritionMealPeriod.fromJson(Map<String, dynamic> json) {
    return NutritionMealPeriod(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      totalCost: _toDouble(json['total_cost']),
      changePct: _toDouble(json['change_pct']),
      mealsServed: _toInt(json['meals_served']),
      averageCostPerMeal: _toDouble(json['average_cost_per_meal']),
      sharePct: _toDouble(json['share_pct']),
      status: json['status']?.toString() ?? 'normal',
    );
  }
}

class NutritionDay {
  const NutritionDay({
    required this.date,
    this.totalCost = 0,
    this.mealsServed = 0,
    this.averageCostPerMeal = 0,
    this.deviationPct = 0,
    this.status = 'normal',
    this.composition = const {},
  });

  final String date;
  final double totalCost;
  final int mealsServed;
  final double averageCostPerMeal;

  /// Отклонение затрат дня от среднего по периоду (Δ к ср.).
  final double deviationPct;
  final String status;

  /// Доли food_group в процентах: `meat_fish`, `fruits`, `dairy`…
  final Map<String, double> composition;

  factory NutritionDay.fromJson(Map<String, dynamic> json) {
    final comp = <String, double>{};
    final raw = json['composition'];
    if (raw is Map) {
      raw.forEach((k, v) => comp[k.toString()] = _toDouble(v));
    }
    return NutritionDay(
      date: json['date']?.toString() ?? '',
      totalCost: _toDouble(json['total_cost']),
      mealsServed: _toInt(json['meals_served']),
      averageCostPerMeal: _toDouble(json['average_cost_per_meal']),
      deviationPct: _toDouble(json['deviation_pct']),
      status: json['status']?.toString() ?? 'normal',
      composition: comp,
    );
  }
}

class NutritionComposition {
  const NutritionComposition({
    required this.foodGroup,
    this.label = '',
    this.actualCost = 0,
    this.actualPct = 0,
    this.targetPct = 0,
    this.deviationPct = 0,
    this.status = 'normal',
  });

  final String foodGroup;
  final String label;
  final double actualCost;
  final double actualPct;
  final double targetPct;
  final double deviationPct;
  final String status;

  factory NutritionComposition.fromJson(Map<String, dynamic> json) {
    return NutritionComposition(
      foodGroup: json['food_group']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      actualCost: _toDouble(json['actual_cost']),
      actualPct: _toDouble(json['actual_pct']),
      targetPct: _toDouble(json['target_pct']),
      deviationPct: _toDouble(json['deviation_pct']),
      status: json['status']?.toString() ?? 'normal',
    );
  }
}

class NutritionForecast {
  const NutritionForecast({
    this.month = '',
    this.actualCostToDate = 0,
    this.projectedCost = 0,
    this.projectedRemaining = 0,
    this.forecastMeals = 0,
    this.basis = '',
    this.confidencePct = 0,
  });

  final String month;
  final double actualCostToDate;
  final double projectedCost;
  final double projectedRemaining;
  final int forecastMeals;
  final String basis;
  final double confidencePct;

  factory NutritionForecast.fromJson(Map<String, dynamic> json) {
    return NutritionForecast(
      month: json['month']?.toString() ?? '',
      actualCostToDate: _toDouble(json['actual_cost_to_date']),
      projectedCost: _toDouble(json['projected_cost']),
      projectedRemaining: _toDouble(json['projected_remaining']),
      forecastMeals: _toInt(json['forecast_meals']),
      basis: json['basis']?.toString() ?? '',
      confidencePct: _toDouble(json['confidence_pct']),
    );
  }
}

class NutritionInsight {
  const NutritionInsight({
    this.source = 'analyst',
    this.severity = 'info',
    this.title = '',
    this.message = '',
  });

  /// `inspector` (алёрты) или `analyst` (эталоны/прогноз).
  final String source;
  final String severity;
  final String title;
  final String message;

  factory NutritionInsight.fromJson(Map<String, dynamic> json) {
    return NutritionInsight(
      source: json['source']?.toString() ?? 'analyst',
      severity: json['severity']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

import 'package:mezzome/features/nutrition/domain/models/nutrition_dashboard.dart';

/// Парсинг `GET /dashboard/nutrition` → доменную модель. Лоялен к Decimal-строкам.
abstract final class NutritionDashboardDto {
  static NutritionDashboard fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    final perms = (json['permissions'] as Map?)?.cast<String, dynamic>();
    final s = (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final f = (json['forecast'] as Map?)?.cast<String, dynamic>();

    return NutritionDashboard(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      summary: NutritionSummary(
        totalCost: _toDouble(s['total_cost']),
        changePct: _toDouble(s['change_pct']),
        mealsServed: _toInt(s['meals_served']),
        averageCostPerMeal: _toDouble(s['average_cost_per_meal']),
        costPerMealChangePct: _toDouble(s['cost_per_meal_change_pct']),
        status: s['status']?.toString() ?? 'normal',
      ),
      mealPeriods: list(
        json['meal_periods'],
        (e) => NutritionMealPeriod(
          code: e['code']?.toString() ?? '',
          name: e['name']?.toString() ?? '',
          totalCost: _toDouble(e['total_cost']),
          changePct: _toDouble(e['change_pct']),
          mealsServed: _toInt(e['meals_served']),
          averageCostPerMeal: _toDouble(e['average_cost_per_meal']),
          sharePct: _toDouble(e['share_pct']),
          status: e['status']?.toString() ?? 'normal',
        ),
      ),
      daily: list(json['daily'], _day),
      composition: list(
        json['composition'],
        (e) => NutritionComposition(
          foodGroup: e['food_group']?.toString() ?? '',
          label: e['label']?.toString() ?? '',
          actualCost: _toDouble(e['actual_cost']),
          actualPct: _toDouble(e['actual_pct']),
          targetPct: _toDouble(e['target_pct']),
          deviationPct: _toDouble(e['deviation_pct']),
          status: e['status']?.toString() ?? 'normal',
        ),
      ),
      insights: list(
        json['insights'],
        (e) => NutritionInsight(
          source: e['source']?.toString() ?? 'analyst',
          severity: e['severity']?.toString() ?? 'info',
          title: e['title']?.toString() ?? '',
          message: e['message']?.toString() ?? '',
        ),
      ),
      forecast: f == null
          ? null
          : NutritionForecast(
              month: f['month']?.toString() ?? '',
              actualCostToDate: _toDouble(f['actual_cost_to_date']),
              projectedCost: _toDouble(f['projected_cost']),
              projectedRemaining: _toDouble(f['projected_remaining']),
              forecastMeals: _toInt(f['forecast_meals']),
              basis: f['basis']?.toString() ?? '',
              confidencePct: _toDouble(f['confidence_pct']),
            ),
      canViewMoney: perms == null ? true : perms['can_view_money'] != false,
    );
  }

  static NutritionDay _day(Map<String, dynamic> json) {
    final comp = <String, double>{};
    final raw = json['composition'];
    if (raw is Map) {
      raw.forEach((k, v) => comp[k.toString()] = _toDouble(v));
    }
    final meals = <NutritionDayMeal>[];
    final rawMeals = json['meal_periods'];
    if (rawMeals is List) {
      for (final e in rawMeals.whereType<Map>()) {
        final m = e.cast<String, dynamic>();
        meals.add(NutritionDayMeal(
          code: m['code']?.toString() ?? '',
          totalCost: _toDouble(m['total_cost']),
          averageCostPerMeal: _toDouble(m['average_cost_per_meal']),
          mealsServed: _toInt(m['meals_served']),
        ));
      }
    }
    return NutritionDay(
      date: json['date']?.toString() ?? '',
      totalCost: _toDouble(json['total_cost']),
      mealsServed: _toInt(json['meals_served']),
      averageCostPerMeal: _toDouble(json['average_cost_per_meal']),
      deviationPct: _toDouble(json['deviation_pct']),
      status: json['status']?.toString() ?? 'normal',
      composition: comp,
      mealPeriods: meals,
    );
  }
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

import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/dashboard/data/models/nutrition_dashboard_model.dart';

const _json = <String, dynamic>{
  'from': '2026-06-01',
  'to': '2026-06-15',
  'permissions': {'can_view_money': true},
  'summary': {
    'total_cost': 6654487.2,
    'change_pct': -11.61,
    'meals_served': 5614,
    'average_cost_per_meal': 1185.34,
    'cost_per_meal_change_pct': 0.04,
    'status': 'normal',
  },
  'meal_periods': [
    {
      'code': 'BREAKFAST',
      'name': 'Завтрак',
      'total_cost': 1386106.8,
      'share_pct': 20.83,
      'meals_served': 1776,
      'average_cost_per_meal': 780.47,
      'status': 'warning',
    },
    {
      'code': 'DINNER',
      'name': 'Ужин',
      'total_cost': 2524036.4,
      'share_pct': 37.93,
      'meals_served': 1663,
      'average_cost_per_meal': 1517.76,
      'status': 'warning',
    },
  ],
  'daily': [
    {
      'date': '2026-06-08',
      'total_cost': 562815.6,
      'meals_served': 427,
      'average_cost_per_meal': 1318.07,
      'deviation_pct': 11.2,
      'status': 'warning',
      'composition': {'meat_fish': 68, 'fruits': 2, 'dairy': 8},
    },
    {
      'date': '2026-06-14',
      'total_cost': 0,
      'meals_served': 0,
      'average_cost_per_meal': 0,
      'deviation_pct': 0,
      'status': 'normal',
      'composition': {'meat_fish': 0},
    },
  ],
  'composition': [
    {
      'food_group': 'meat_fish',
      'label': 'Мясо и рыба',
      'actual_cost': 2283729.92,
      'actual_pct': 35.12,
      'target_pct': 32,
      'deviation_pct': 3.12,
      'status': 'normal',
    },
  ],
  'forecast': {
    'month': '2026-06',
    'actual_cost_to_date': 6654487.2,
    'projected_cost': 14441814.23,
    'forecast_meals': 12194,
    'basis': 'headcount_forecast',
    'confidence_pct': 98,
  },
  'insights': [
    {
      'source': 'analyst',
      'severity': 'info',
      'title': 'Прогноз питания на месяц',
      'message': 'Прогноз затрат...',
    },
  ],
};

void main() {
  group('NutritionDashboard.fromJson', () {
    test('parses summary, meal periods, daily composition, forecast', () {
      final d = NutritionDashboard.fromJson(_json);
      expect(d.canViewMoney, isTrue);
      expect(d.summary.totalCost, 6654487.2);
      expect(d.summary.mealsServed, 5614);
      expect(d.mealPeriods, hasLength(2));
      expect(d.mealByCode('breakfast')?.sharePct, 20.83); // регистр игнор
      expect(d.mealByCode('DINNER')?.status, 'warning');
      expect(d.daily.first.composition['meat_fish'], 68);
      expect(d.daily.first.deviationPct, 11.2);
      expect(d.composition.single.targetPct, 32);
      expect(d.forecast?.projectedCost, 14441814.23);
      expect(d.insights.single.source, 'analyst');
    });

    test('mealByCode returns null for missing meal', () {
      final d = NutritionDashboard.fromJson(_json);
      expect(d.mealByCode('LUNCH'), isNull);
    });

    test('empty json yields safe empty dashboard', () {
      final d = NutritionDashboard.fromJson(const {});
      expect(d.daily, isEmpty);
      expect(d.mealPeriods, isEmpty);
      expect(d.forecast, isNull);
      expect(d.summary.totalCost, 0);
      expect(d.canViewMoney, isTrue);
    });
  });
}

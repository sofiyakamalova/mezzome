/// Доменные модели «Сводной по питанию» (гайд §20). Чистые, без JSON.
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
    this.mealPeriods = const [],
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

  /// Разбивка дня по приёмам (`daily[].meal_periods`): сумма и СРМ завтрака/
  /// обеда/ужина. Состава (мясо/фрукты) здесь нет — бэк его по приёму не отдаёт.
  final List<NutritionDayMeal> mealPeriods;

  /// Приём пищи дня по коду (`BREAKFAST`/`LUNCH`/`DINNER`), null если нет.
  NutritionDayMeal? mealByCode(String code) {
    for (final m in mealPeriods) {
      if (m.code.toUpperCase() == code.toUpperCase()) return m;
    }
    return null;
  }
}

/// Приём пищи в рамках одного дня (`daily[].meal_periods[]`).
class NutritionDayMeal {
  const NutritionDayMeal({
    required this.code,
    this.totalCost = 0,
    this.averageCostPerMeal = 0,
    this.mealsServed = 0,
  });

  final String code;
  final double totalCost;
  final double averageCostPerMeal;
  final int mealsServed;
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
}

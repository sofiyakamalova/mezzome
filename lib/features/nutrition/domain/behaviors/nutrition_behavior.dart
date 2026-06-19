import 'package:mezzome/features/nutrition/domain/models/nutrition_dashboard.dart';

/// Контракт доступа к «Сводной по питанию». `null` — данные недоступны.
abstract class NutritionBehavior {
  Future<NutritionDashboard?> getNutrition({
    required String from,
    required String to,
  });
}

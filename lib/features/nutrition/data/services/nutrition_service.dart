import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/nutrition/data/sources/nutrition_remote_source.dart';
import 'package:mezzome/features/nutrition/domain/behaviors/nutrition_behavior.dart';
import 'package:mezzome/features/nutrition/domain/models/nutrition_dashboard.dart';

/// Реализация [NutritionBehavior]: source + best-effort обработка ошибок.
class NutritionService implements NutritionBehavior {
  const NutritionService(this._source);

  final NutritionRemoteSource _source;

  @override
  Future<NutritionDashboard?> getNutrition({
    required String from,
    required String to,
  }) async {
    try {
      return await _source.getNutrition(from: from, to: to);
    } on DioException catch (e) {
      appLogger.w('Nutrition dashboard failed: ${e.message}');
      return null;
    } catch (e) {
      appLogger.w('Nutrition dashboard failed: $e');
      return null;
    }
  }
}

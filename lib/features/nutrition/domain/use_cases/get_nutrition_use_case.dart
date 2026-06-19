import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/nutrition/domain/behaviors/nutrition_behavior.dart';
import 'package:mezzome/features/nutrition/domain/models/nutrition_dashboard.dart';

/// «Сводная по питанию» за выбранный период. Эндпоинт работает по from/to,
/// поэтому период (day/week/month/year) превращаем в диапазон здесь.
class GetNutritionUseCase {
  const GetNutritionUseCase(this._behavior);

  final NutritionBehavior _behavior;

  Future<NutritionDashboard?> call({
    required String period,
    required DateTime date,
  }) {
    final range = _range(period, date);
    return _behavior.getNutrition(from: range.from, to: range.to);
  }

  ({String from, String to}) _range(String period, DateTime d) {
    switch (period) {
      case 'day':
        final s = DateFormatUtil.apiDate(d);
        return (from: s, to: s);
      case 'week':
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return (
          from: DateFormatUtil.apiDate(monday),
          to: DateFormatUtil.apiDate(monday.add(const Duration(days: 6))),
        );
      case 'year':
        return (
          from: DateFormatUtil.apiDate(DateTime(d.year, 1, 1)),
          to: DateFormatUtil.apiDate(DateTime(d.year, 12, 31)),
        );
      case 'month':
      default:
        return (
          from: DateFormatUtil.apiDate(DateTime(d.year, d.month, 1)),
          to: DateFormatUtil.apiDate(DateTime(d.year, d.month + 1, 0)),
        );
    }
  }
}

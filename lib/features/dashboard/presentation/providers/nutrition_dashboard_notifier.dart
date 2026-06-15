import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dashboard/data/models/nutrition_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';

/// «Сводная по питанию» (`GET /dashboard/nutrition`). Эндпоинт работает по
/// [from]/[to], поэтому выбранный период (day/week/month/year) превращаем в
/// диапазон на фронте. Загрузка best-effort: при недоступности → `null`.
class NutritionDashboardNotifier extends AsyncNotifier<NutritionDashboard?> {
  String _period = 'month';
  late final DateTime _date = DateFormatUtil.today;

  String get period => _period;

  @override
  Future<NutritionDashboard?> build() => _load();

  /// Границы периода (включительно для `to`) на опорную дату.
  ({String from, String to}) _range() {
    final d = _date;
    switch (_period) {
      case 'day':
        final s = DateFormatUtil.apiDate(d);
        return (from: s, to: s);
      case 'week':
        final monday = d.subtract(Duration(days: d.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return (
          from: DateFormatUtil.apiDate(monday),
          to: DateFormatUtil.apiDate(sunday),
        );
      case 'year':
        return (
          from: DateFormatUtil.apiDate(DateTime(d.year, 1, 1)),
          to: DateFormatUtil.apiDate(DateTime(d.year, 12, 31)),
        );
      case 'month':
      default:
        final last = DateTime(d.year, d.month + 1, 0); // 0-й день след. месяца
        return (
          from: DateFormatUtil.apiDate(DateTime(d.year, d.month, 1)),
          to: DateFormatUtil.apiDate(last),
        );
    }
  }

  Future<NutritionDashboard?> _load() {
    final r = _range();
    return ref
        .read(dashboardRepositoryProvider)
        .fetchNutrition(from: r.from, to: r.to);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<NutritionDashboard?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<void> setPeriod(String period) async {
    if (period == _period) return;
    _period = period;
    state = const AsyncLoading<NutritionDashboard?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final nutritionDashboardNotifierProvider =
    AsyncNotifierProvider<NutritionDashboardNotifier, NutritionDashboard?>(
  NutritionDashboardNotifier.new,
);

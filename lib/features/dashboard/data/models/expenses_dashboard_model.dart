/// Дашборд расходов (`GET /api/v2/dashboard/expenses?period=&date=`, §8 гайда).
///
/// Чисто расходный срез: суммы по категориям и общий итог за период. Выручки
/// и продаж здесь нет по дизайну — экран показывает только расход.
///
/// Бэкенд (Django `DecimalField`) может присылать деньги строкой
/// (`"125000.0000"`), поэтому парсим лояльно к числам и строкам.
class ExpensesDashboardModel {
  const ExpensesDashboardModel({
    this.byCategory = const {},
    this.total = 0,
    this.availableCategories = const [],
  });

  /// Сумма расходов по категориям: `category -> amount`.
  final Map<String, double> byCategory;

  /// Общая сумма расходов за период.
  final double total;

  /// Категории, которые backend считает допустимыми для этого тенанта.
  final List<String> availableCategories;

  factory ExpensesDashboardModel.fromJson(Map<String, dynamic> json) {
    final byCategory = <String, double>{};
    final raw = json['by_category'];
    if (raw is Map) {
      raw.forEach((key, value) {
        byCategory[key.toString()] = _toDouble(value);
      });
    }

    final categories =
        (json['available_categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return ExpensesDashboardModel(
      byCategory: byCategory,
      total: _toDouble(json['total']),
      availableCategories: categories,
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

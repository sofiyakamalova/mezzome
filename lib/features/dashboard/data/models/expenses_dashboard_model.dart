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
    this.byBranch = const [],
    this.total = 0,
    this.availableCategories = const [],
  });

  /// Сумма расходов по категориям: `category -> amount`.
  final Map<String, double> byCategory;

  /// Расходы по филиалам с разбивкой по категориям (гайд §8). Нужны для
  /// построчной расшифровки расходов в карточке объекта.
  final List<ExpensesByBranch> byBranch;

  /// Общая сумма расходов за период.
  final double total;

  /// Категории, которые backend считает допустимыми для этого тенанта.
  final List<String> availableCategories;

  factory ExpensesDashboardModel.fromJson(Map<String, dynamic> json) {
    final byCategory = _parseCategoryMap(json['by_category']);

    final rawByBranch = json['by_branch'];
    final byBranch = rawByBranch is List
        ? rawByBranch
              .whereType<Map>()
              .map((e) => ExpensesByBranch.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const <ExpensesByBranch>[];

    final categories =
        (json['available_categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return ExpensesDashboardModel(
      byCategory: byCategory,
      byBranch: byBranch,
      total: _toDouble(json['total']),
      availableCategories: categories,
    );
  }
}

/// Расходы одного филиала с разбивкой по категориям (`by_branch[]`).
class ExpensesByBranch {
  const ExpensesByBranch({
    required this.branchId,
    this.byCategory = const {},
    this.total = 0,
  });

  final int branchId;
  final Map<String, double> byCategory;
  final double total;

  factory ExpensesByBranch.fromJson(Map<String, dynamic> json) {
    return ExpensesByBranch(
      branchId: _toInt(json['branch_id']),
      byCategory: _parseCategoryMap(json['by_category']),
      total: _toDouble(json['total']),
    );
  }
}

Map<String, double> _parseCategoryMap(Object? raw) {
  final map = <String, double>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      map[key.toString()] = _toDouble(value);
    });
  }
  return map;
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

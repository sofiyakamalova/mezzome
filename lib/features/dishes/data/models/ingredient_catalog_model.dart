/// Модели справочника ингредиентов и ингредиентов блюда.
///
/// Ответы соответствующих ручек в swagger нетипизированы (`{items, total}` без
/// описания полей — «контракт опережает swagger»), поэтому парсим лояльно:
/// допускаем разные имена полей (`id`/`ingredient_id`, `name`/`ingredient_name`)
/// и пропускаем строки, из которых нельзя достать обязательное.
library;

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String? _asString(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Достаёт список элементов из тела ответа: `{items: [...]}`,
/// `{ingredients: [...]}` или голый массив.
List<Map<String, dynamic>> ingredientItemsFromResponse(dynamic data) {
  final dynamic raw = data is Map
      ? (data['items'] ?? data['ingredients'] ?? data['data'] ?? const [])
      : data;
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
  return const [];
}

/// Элемент справочника ингредиентов кухни
/// (`GET /kitchens/{kitchen_id}/ingredients`, ~`dto.DetailedIngredientResponse`).
class IngredientCatalogItem {
  const IngredientCatalogItem({
    required this.id,
    required this.name,
    this.unit,
    this.costPerUnit,
    this.category,
  });

  /// id записи справочника — это и есть `ingredient_id` для техкарты.
  final int id;
  final String name;
  final String? unit;
  final double? costPerUnit;
  final String? category;

  /// `null`, если из строки нельзя достать id+name (тогда её пропускаем).
  static IngredientCatalogItem? tryParse(Map<String, dynamic> json) {
    final id = _asInt(json['id'] ?? json['ingredient_id']);
    final name = _asString(json['name'] ?? json['ingredient_name']);
    if (id == null || name == null) return null;
    return IngredientCatalogItem(
      id: id,
      name: name,
      unit: _asString(json['unit']),
      costPerUnit: json['cost_per_unit'] == null
          ? null
          : _asDouble(json['cost_per_unit']),
      category: _asString(json['category']),
    );
  }
}

/// Ингредиент в рецепте блюда
/// (`GET /menu-items/{menu_item_id}/ingredients`, ~`dto.IngredientInfo`).
class DishIngredient {
  const DishIngredient({
    this.ingredientId,
    required this.name,
    this.brutto = 0,
    this.netto = 0,
    this.unit,
    this.costPerUnit = 0,
    this.itemType,
    this.preparationTypeId,
  });

  /// `ingredient_id` строки рецепта. Пустой у полуфабрикатов (они задаются
  /// `preparation_type_id`) — такие строки техкарта по `ingredient_id` пока
  /// не принимает.
  final int? ingredientId;
  final String name;
  final double brutto;
  final double netto;
  final String? unit;
  final double costPerUnit;
  final String? itemType;
  final int? preparationTypeId;

  /// Полуфабрикат (а не сырой ингредиент): нет `ingredient_id`, но есть тип/
  /// `preparation_type_id`. В техкарту по `ingredient_id` не отправляется.
  bool get isPreparation =>
      ingredientId == null &&
      (preparationTypeId != null ||
          (itemType != null && itemType != 'ingredient'));

  factory DishIngredient.fromJson(Map<String, dynamic> json) {
    return DishIngredient(
      ingredientId: _asInt(json['ingredient_id']),
      name: _asString(json['name'] ?? json['ingredient_name']) ?? '',
      brutto: _asDouble(json['brutto'] ?? json['amount']),
      netto: _asDouble(json['netto'] ?? json['amount']),
      unit: _asString(json['unit']),
      costPerUnit: _asDouble(json['cost_per_unit']),
      itemType: _asString(json['item_type']),
      preparationTypeId: _asInt(json['preparation_type_id']),
    );
  }
}

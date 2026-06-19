import 'package:mezzome/features/dishes/domain/models/production_grid.dart';

/// Парсинг `GET /{role}/production-plans/grid` → доменную модель.
abstract final class ProductionGridDto {
  static ProductionPlanGridResponse fromJson(Map<String, dynamic> json) {
    return ProductionPlanGridResponse(
      weekStart: json['week_start']?.toString(),
      weekEnd: json['week_end']?.toString(),
      serviceType: json['service_type']?.toString(),
      serviceTypeTitle: json['service_type_title']?.toString(),
      kitchenId: _toIntOrNull(json['kitchen_id']),
      days: _list(json['days'], _day),
      rows: _list(json['rows'], _row),
    );
  }

  static ProductionPlanGridDay _day(Map<String, dynamic> j) =>
      ProductionPlanGridDay(
        date: j['date']?.toString(),
        weekday: j['weekday']?.toString(),
        weekdayTitle: j['weekday_title']?.toString(),
        planIds: _intList(j['plan_ids']),
        peopleCount: _toInt(j['people_count']),
        totalPortions: _toInt(j['total_portions']),
      );

  static ProductionPlanGridRow _row(Map<String, dynamic> j) =>
      ProductionPlanGridRow(
        slotKey: j['slot_key']?.toString(),
        slotTitle: j['slot_title']?.toString(),
        sortOrder: _toInt(j['sort_order']),
        cells: _list(j['cells'], _cell),
      );

  static ProductionPlanGridCell _cell(Map<String, dynamic> j) =>
      ProductionPlanGridCell(
        date: j['date']?.toString(),
        weekday: j['weekday']?.toString(),
        weekdayTitle: j['weekday_title']?.toString(),
        items: _list(j['items'], _item),
      );

  static ProductionPlanGridCellItem _item(Map<String, dynamic> j) =>
      ProductionPlanGridCellItem(
        categoryId: _toIntOrNull(j['category_id']),
        categoryName: j['category_name']?.toString(),
        kitchenId: _toIntOrNull(j['kitchen_id']),
        menuItemId: _toIntOrNull(j['menu_item_id']),
        menuItemName: j['menu_item_name']?.toString(),
        planId: _toIntOrNull(j['plan_id']),
        planItemId: _toIntOrNull(j['plan_item_id']),
        plannedPortions: _toInt(j['planned_portions']),
        status: j['status']?.toString(),
        stockAvailable: j['stock_available'] as bool?,
        theoreticalCost: _toDoubleOrNull(j['theoretical_cost']),
        technicalCardId: _toIntOrNull(j['technical_card_id']),
        technicalCardRootId: _toIntOrNull(j['technical_card_root_id']),
        technicalCardVersion: _toIntOrNull(j['technical_card_version']),
        technicalCardName: j['technical_card_name']?.toString(),
        technicalCardBasePortions:
            _toIntOrNull(j['technical_card_base_portions']),
        technicalCardFoodCost: _toDoubleOrNull(j['technical_card_food_cost']),
        technicalCardOutputUnit: j['technical_card_output_unit']?.toString(),
        technicalCardOutputPerPortion:
            _toDoubleOrNull(j['technical_card_output_per_portion']),
        warnings: (j['warnings'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(e.cast<String, dynamic>()))
      .toList();
}

List<int> _intList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map(_toInt).toList();
}

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

int? _toIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _toDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

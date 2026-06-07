// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'production_plan_grid_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductionPlanGridResponse _$ProductionPlanGridResponseFromJson(
  Map<String, dynamic> json,
) => ProductionPlanGridResponse(
  weekStart: json['week_start'] as String?,
  weekEnd: json['week_end'] as String?,
  serviceType: json['service_type'] as String?,
  serviceTypeTitle: json['service_type_title'] as String?,
  kitchenId: (json['kitchen_id'] as num?)?.toInt(),
  days:
      (json['days'] as List<dynamic>?)
          ?.map(
            (e) => ProductionPlanGridDay.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  rows:
      (json['rows'] as List<dynamic>?)
          ?.map(
            (e) => ProductionPlanGridRow.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProductionPlanGridResponseToJson(
  ProductionPlanGridResponse instance,
) => <String, dynamic>{
  'week_start': instance.weekStart,
  'week_end': instance.weekEnd,
  'service_type': instance.serviceType,
  'service_type_title': instance.serviceTypeTitle,
  'kitchen_id': instance.kitchenId,
  'days': instance.days.map((e) => e.toJson()).toList(),
  'rows': instance.rows.map((e) => e.toJson()).toList(),
};

ProductionPlanGridDay _$ProductionPlanGridDayFromJson(
  Map<String, dynamic> json,
) => ProductionPlanGridDay(
  date: json['date'] as String?,
  weekday: json['weekday'] as String?,
  weekdayTitle: json['weekday_title'] as String?,
  planIds:
      (json['plan_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  peopleCount: (json['people_count'] as num?)?.toInt() ?? 0,
  totalPortions: (json['total_portions'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ProductionPlanGridDayToJson(
  ProductionPlanGridDay instance,
) => <String, dynamic>{
  'date': instance.date,
  'weekday': instance.weekday,
  'weekday_title': instance.weekdayTitle,
  'plan_ids': instance.planIds,
  'people_count': instance.peopleCount,
  'total_portions': instance.totalPortions,
};

ProductionPlanGridRow _$ProductionPlanGridRowFromJson(
  Map<String, dynamic> json,
) => ProductionPlanGridRow(
  slotKey: json['slot_key'] as String?,
  slotTitle: json['slot_title'] as String?,
  sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  cells:
      (json['cells'] as List<dynamic>?)
          ?.map(
            (e) => ProductionPlanGridCell.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProductionPlanGridRowToJson(
  ProductionPlanGridRow instance,
) => <String, dynamic>{
  'slot_key': instance.slotKey,
  'slot_title': instance.slotTitle,
  'sort_order': instance.sortOrder,
  'cells': instance.cells.map((e) => e.toJson()).toList(),
};

ProductionPlanGridCell _$ProductionPlanGridCellFromJson(
  Map<String, dynamic> json,
) => ProductionPlanGridCell(
  date: json['date'] as String?,
  weekday: json['weekday'] as String?,
  weekdayTitle: json['weekday_title'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map(
            (e) =>
                ProductionPlanGridCellItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProductionPlanGridCellToJson(
  ProductionPlanGridCell instance,
) => <String, dynamic>{
  'date': instance.date,
  'weekday': instance.weekday,
  'weekday_title': instance.weekdayTitle,
  'items': instance.items.map((e) => e.toJson()).toList(),
};

ProductionPlanGridCellItem _$ProductionPlanGridCellItemFromJson(
  Map<String, dynamic> json,
) => ProductionPlanGridCellItem(
  categoryId: (json['category_id'] as num?)?.toInt(),
  categoryName: json['category_name'] as String?,
  kitchenId: (json['kitchen_id'] as num?)?.toInt(),
  menuItemId: (json['menu_item_id'] as num?)?.toInt(),
  menuItemName: json['menu_item_name'] as String?,
  planId: (json['plan_id'] as num?)?.toInt(),
  planItemId: (json['plan_item_id'] as num?)?.toInt(),
  plannedPortions: (json['planned_portions'] as num?)?.toInt() ?? 0,
  status: json['status'] as String?,
  stockAvailable: json['stock_available'] as bool?,
  theoreticalCost: (json['theoretical_cost'] as num?)?.toDouble(),
  technicalCardId: (json['technical_card_id'] as num?)?.toInt(),
  technicalCardRootId: (json['technical_card_root_id'] as num?)?.toInt(),
  technicalCardVersion: (json['technical_card_version'] as num?)?.toInt(),
  technicalCardName: json['technical_card_name'] as String?,
  technicalCardBasePortions: (json['technical_card_base_portions'] as num?)
      ?.toInt(),
  technicalCardFoodCost: (json['technical_card_food_cost'] as num?)?.toDouble(),
  technicalCardOutputUnit: json['technical_card_output_unit'] as String?,
  technicalCardOutputPerPortion:
      (json['technical_card_output_per_portion'] as num?)?.toDouble(),
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$ProductionPlanGridCellItemToJson(
  ProductionPlanGridCellItem instance,
) => <String, dynamic>{
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'kitchen_id': instance.kitchenId,
  'menu_item_id': instance.menuItemId,
  'menu_item_name': instance.menuItemName,
  'plan_id': instance.planId,
  'plan_item_id': instance.planItemId,
  'planned_portions': instance.plannedPortions,
  'status': instance.status,
  'stock_available': instance.stockAvailable,
  'theoretical_cost': instance.theoreticalCost,
  'technical_card_id': instance.technicalCardId,
  'technical_card_root_id': instance.technicalCardRootId,
  'technical_card_version': instance.technicalCardVersion,
  'technical_card_name': instance.technicalCardName,
  'technical_card_base_portions': instance.technicalCardBasePortions,
  'technical_card_food_cost': instance.technicalCardFoodCost,
  'technical_card_output_unit': instance.technicalCardOutputUnit,
  'technical_card_output_per_portion': instance.technicalCardOutputPerPortion,
  'warnings': instance.warnings,
};

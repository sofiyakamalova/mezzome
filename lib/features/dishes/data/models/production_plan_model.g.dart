// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'production_plan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductionPlanListResponse _$ProductionPlanListResponseFromJson(
  Map<String, dynamic> json,
) => ProductionPlanListResponse(
  plans:
      (json['plans'] as List<dynamic>?)
          ?.map(
            (e) => ProductionPlanListItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProductionPlanListResponseToJson(
  ProductionPlanListResponse instance,
) => <String, dynamic>{'plans': instance.plans.map((e) => e.toJson()).toList()};

ProductionPlanListItem _$ProductionPlanListItemFromJson(
  Map<String, dynamic> json,
) => ProductionPlanListItem(
  id: (json['id'] as num).toInt(),
  serviceType: json['service_type'] as String?,
  status: json['status'] as String?,
  plannedDate: json['planned_date'] as String?,
  totalPortions: (json['total_portions'] as num?)?.toInt() ?? 0,
  totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
  kitchenId: (json['kitchen_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductionPlanListItemToJson(
  ProductionPlanListItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'service_type': instance.serviceType,
  'status': instance.status,
  'planned_date': instance.plannedDate,
  'total_portions': instance.totalPortions,
  'total_cost': instance.totalCost,
  'kitchen_id': instance.kitchenId,
};

ProductionPlanDetail _$ProductionPlanDetailFromJson(
  Map<String, dynamic> json,
) => ProductionPlanDetail(
  id: (json['id'] as num).toInt(),
  serviceType: json['service_type'] as String?,
  status: json['status'] as String?,
  plannedDate: json['planned_date'] as String?,
  kitchenId: (json['kitchen_id'] as num?)?.toInt(),
  peopleCount: (json['people_count'] as num?)?.toInt(),
  reserveCoefficient: _dn(json['reserve_coefficient']),
  notes: json['notes'] as String?,
  createdAt: json['created_at'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => ProductionPlanItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProductionPlanDetailToJson(
  ProductionPlanDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'service_type': instance.serviceType,
  'status': instance.status,
  'planned_date': instance.plannedDate,
  'kitchen_id': instance.kitchenId,
  'people_count': instance.peopleCount,
  'reserve_coefficient': instance.reserveCoefficient,
  'notes': instance.notes,
  'created_at': instance.createdAt,
  'items': instance.items.map((e) => e.toJson()).toList(),
};

ProductionPlanItem _$ProductionPlanItemFromJson(Map<String, dynamic> json) =>
    ProductionPlanItem(
      id: (json['id'] as num).toInt(),
      menuItemId: (json['menu_item_id'] as num).toInt(),
      planId: (json['plan_id'] as num?)?.toInt(),
      plannedPortions: (json['planned_portions'] as num?)?.toInt() ?? 0,
      theoreticalCost: json['theoretical_cost'] == null
          ? 0
          : _d(json['theoretical_cost']),
      technicalCardId: (json['technical_card_id'] as num?)?.toInt(),
      slotKey: json['slot_key'] as String?,
      slotTitle: json['slot_title'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      stockAvailable: json['stock_available'] as bool?,
    );

Map<String, dynamic> _$ProductionPlanItemToJson(ProductionPlanItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'menu_item_id': instance.menuItemId,
      'plan_id': instance.planId,
      'planned_portions': instance.plannedPortions,
      'theoretical_cost': instance.theoreticalCost,
      'technical_card_id': instance.technicalCardId,
      'slot_key': instance.slotKey,
      'slot_title': instance.slotTitle,
      'sort_order': instance.sortOrder,
      'stock_available': instance.stockAvailable,
    };

ProductionPlanStockCheck _$ProductionPlanStockCheckFromJson(
  Map<String, dynamic> json,
) => ProductionPlanStockCheck(
  canFulfill: json['can_fulfill'] as bool? ?? false,
  totalCost: json['total_cost'] == null ? 0 : _d(json['total_cost']),
  shortages:
      (json['shortages'] as List<dynamic>?)
          ?.map(
            (e) =>
                ProductionPlanStockShortage.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

ProductionPlanStockShortage _$ProductionPlanStockShortageFromJson(
  Map<String, dynamic> json,
) => ProductionPlanStockShortage(
  ingredient: json['ingredient'] as String?,
  ingredientId: (json['ingredient_id'] as num?)?.toInt(),
  requiredQty: json['required_qty'] == null ? 0 : _d(json['required_qty']),
  availableQty: json['available_qty'] == null ? 0 : _d(json['available_qty']),
  deficitQty: json['deficit_qty'] == null ? 0 : _d(json['deficit_qty']),
  unit: json['unit'] as String?,
);

UpdateProductionPlanItemRequest _$UpdateProductionPlanItemRequestFromJson(
  Map<String, dynamic> json,
) => UpdateProductionPlanItemRequest(
  plannedPortions: (json['planned_portions'] as num?)?.toInt(),
  menuItemId: (json['menu_item_id'] as num?)?.toInt(),
  slotKey: json['slot_key'] as String?,
  slotTitle: json['slot_title'] as String?,
  sortOrder: (json['sort_order'] as num?)?.toInt(),
);

Map<String, dynamic> _$UpdateProductionPlanItemRequestToJson(
  UpdateProductionPlanItemRequest instance,
) => <String, dynamic>{
  if (instance.plannedPortions case final value?) 'planned_portions': value,
  if (instance.menuItemId case final value?) 'menu_item_id': value,
  if (instance.slotKey case final value?) 'slot_key': value,
  if (instance.slotTitle case final value?) 'slot_title': value,
  if (instance.sortOrder case final value?) 'sort_order': value,
};

KitchenModel _$KitchenModelFromJson(Map<String, dynamic> json) => KitchenModel(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String?,
);

Map<String, dynamic> _$KitchenModelToJson(KitchenModel instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

Map<String, dynamic> _$ProductionPlanItemInputToJson(
  ProductionPlanItemInput instance,
) => <String, dynamic>{
  'menu_item_id': instance.menuItemId,
  'planned_portions': instance.plannedPortions,
  if (instance.slotKey case final value?) 'slot_key': value,
  if (instance.slotTitle case final value?) 'slot_title': value,
  if (instance.sortOrder case final value?) 'sort_order': value,
};

Map<String, dynamic> _$ProductionPlanCreateRequestToJson(
  ProductionPlanCreateRequest instance,
) => <String, dynamic>{
  'kitchen_id': instance.kitchenId,
  'service_type': instance.serviceType,
  'planned_date': instance.plannedDate,
  if (instance.peopleCount case final value?) 'people_count': value,
  if (instance.reserveCoefficient case final value?)
    'reserve_coefficient': value,
  if (instance.notes case final value?) 'notes': value,
  'items': instance.items.map((e) => e.toJson()).toList(),
};

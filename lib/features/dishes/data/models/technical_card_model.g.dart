// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'technical_card_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TechnicalCardListResponse _$TechnicalCardListResponseFromJson(
  Map<String, dynamic> json,
) => TechnicalCardListResponse(
  cards:
      (json['cards'] as List<dynamic>?)
          ?.map((e) => TechnicalCardModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  total: (json['total'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TechnicalCardListResponseToJson(
  TechnicalCardListResponse instance,
) => <String, dynamic>{
  'cards': instance.cards.map((e) => e.toJson()).toList(),
  'total': instance.total,
};

TechnicalCardModel _$TechnicalCardModelFromJson(Map<String, dynamic> json) =>
    TechnicalCardModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      menuItemId: (json['menu_item_id'] as num?)?.toInt(),
      description: json['description'] as String?,
      basePortions: (json['base_portions'] as num?)?.toDouble() ?? 1,
      outputPerPortion: (json['output_per_portion'] as num?)?.toDouble() ?? 0,
      outputUnit: json['output_unit'] as String? ?? 'g',
      totalIngredientCost:
          (json['total_ingredient_cost'] as num?)?.toDouble() ?? 0,
      foodCost: (json['food_cost'] as num?)?.toDouble() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name'] as String?,
      status: json['status'] as String?,
      approvalStatus: json['approval_status'] as String?,
      availableActions:
          (json['available_actions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      version: (json['version'] as num?)?.toInt(),
      changeLevel: json['change_level'] as String?,
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String),
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.parse(json['approved_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      halalRequired: json['halal_required'] as bool? ?? false,
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map(
                (e) => TechnicalCardIngredientModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      code: json['code'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      createdBy: (json['created_by'] as num?)?.toInt(),
      isLatest: json['is_latest'] as bool? ?? false,
      approvalReason: json['approval_reason'] as String?,
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map(
                (e) =>
                    TechnicalCardStepModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TechnicalCardModelToJson(TechnicalCardModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'menu_item_id': instance.menuItemId,
      'description': instance.description,
      'base_portions': instance.basePortions,
      'output_per_portion': instance.outputPerPortion,
      'output_unit': instance.outputUnit,
      'total_ingredient_cost': instance.totalIngredientCost,
      'food_cost': instance.foodCost,
      'category_id': instance.categoryId,
      'category_name': instance.categoryName,
      'status': instance.status,
      'approval_status': instance.approvalStatus,
      'available_actions': instance.availableActions,
      'version': instance.version,
      'change_level': instance.changeLevel,
      'submitted_at': instance.submittedAt?.toIso8601String(),
      'approved_at': instance.approvedAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'halal_required': instance.halalRequired,
      'ingredients': instance.ingredients.map((e) => e.toJson()).toList(),
      'code': instance.code,
      'created_at': instance.createdAt?.toIso8601String(),
      'created_by': instance.createdBy,
      'is_latest': instance.isLatest,
      'approval_reason': instance.approvalReason,
      'steps': instance.steps.map((e) => e.toJson()).toList(),
    };

TechnicalCardIngredientModel _$TechnicalCardIngredientModelFromJson(
  Map<String, dynamic> json,
) => TechnicalCardIngredientModel(
  id: (json['id'] as num).toInt(),
  ingredientId: (json['ingredient_id'] as num?)?.toInt(),
  ingredientName: json['ingredient_name'] as String?,
  brutto: (json['brutto'] as num?)?.toDouble() ?? 0,
  netto: (json['netto'] as num?)?.toDouble() ?? 0,
  costPerUnit: (json['cost_per_unit'] as num?)?.toDouble() ?? 0,
  totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
  unit: json['unit'] as String?,
  cleaningPct: (json['cleaning_pct'] as num?)?.toDouble(),
  cutType: json['cut_type'] as String?,
  nettoPerPortion: (json['netto_per_portion'] as num?)?.toDouble(),
);

Map<String, dynamic> _$TechnicalCardIngredientModelToJson(
  TechnicalCardIngredientModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'ingredient_id': instance.ingredientId,
  'ingredient_name': instance.ingredientName,
  'brutto': instance.brutto,
  'netto': instance.netto,
  'cost_per_unit': instance.costPerUnit,
  'total_cost': instance.totalCost,
  'unit': instance.unit,
  'cleaning_pct': instance.cleaningPct,
  'cut_type': instance.cutType,
  'netto_per_portion': instance.nettoPerPortion,
};

TechnicalCardStepModel _$TechnicalCardStepModelFromJson(
  Map<String, dynamic> json,
) => TechnicalCardStepModel(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String?,
  description: json['description'] as String?,
  sortOrder: (json['sort_order'] as num?)?.toInt(),
  durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
  temperatureC: (json['temperature_c'] as num?)?.toDouble(),
  kitchenSection: json['kitchen_section'] as String?,
);

Map<String, dynamic> _$TechnicalCardStepModelToJson(
  TechnicalCardStepModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'sort_order': instance.sortOrder,
  'duration_minutes': instance.durationMinutes,
  'temperature_c': instance.temperatureC,
  'kitchen_section': instance.kitchenSection,
};

UpdateTechnicalCardRequest _$UpdateTechnicalCardRequestFromJson(
  Map<String, dynamic> json,
) => UpdateTechnicalCardRequest(
  name: json['name'] as String?,
  description: json['description'] as String?,
  basePortions: (json['base_portions'] as num?)?.toDouble(),
  outputPerPortion: (json['output_per_portion'] as num?)?.toDouble(),
  outputUnit: json['output_unit'] as String?,
  ingredients: (json['ingredients'] as List<dynamic>?)
      ?.map(
        (e) => TechnicalCardIngredientInput.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  menuItemId: (json['menu_item_id'] as num?)?.toInt(),
  halalRequired: json['halal_required'] as bool? ?? false,
  submitForApproval: json['submit_for_approval'] as bool?,
  approvalReason: json['approval_reason'] as String?,
);

Map<String, dynamic> _$UpdateTechnicalCardRequestToJson(
  UpdateTechnicalCardRequest instance,
) => <String, dynamic>{
  if (instance.name case final value?) 'name': value,
  if (instance.description case final value?) 'description': value,
  if (instance.basePortions case final value?) 'base_portions': value,
  if (instance.outputPerPortion case final value?) 'output_per_portion': value,
  if (instance.outputUnit case final value?) 'output_unit': value,
  if (instance.ingredients?.map((e) => e.toJson()).toList() case final value?)
    'ingredients': value,
  if (instance.approvalReason case final value?) 'approval_reason': value,
  if (instance.menuItemId case final value?) 'menu_item_id': value,
  'halal_required': instance.halalRequired,
  if (instance.submitForApproval case final value?)
    'submit_for_approval': value,
};

TechnicalCardIngredientInput _$TechnicalCardIngredientInputFromJson(
  Map<String, dynamic> json,
) => TechnicalCardIngredientInput(
  ingredientId: (json['ingredient_id'] as num?)?.toInt(),
  ingredientName: json['ingredient_name'] as String?,
  brutto: (json['brutto'] as num?)?.toDouble(),
  netto: (json['netto'] as num?)?.toDouble(),
  costPerUnit: (json['cost_per_unit'] as num?)?.toDouble(),
  sortOrder: (json['sort_order'] as num?)?.toInt(),
);

Map<String, dynamic> _$TechnicalCardIngredientInputToJson(
  TechnicalCardIngredientInput instance,
) => <String, dynamic>{
  if (instance.ingredientId case final value?) 'ingredient_id': value,
  if (instance.ingredientName case final value?) 'ingredient_name': value,
  if (instance.brutto case final value?) 'brutto': value,
  if (instance.netto case final value?) 'netto': value,
  if (instance.costPerUnit case final value?) 'cost_per_unit': value,
  if (instance.sortOrder case final value?) 'sort_order': value,
};

AuditLogListResponse _$AuditLogListResponseFromJson(
  Map<String, dynamic> json,
) => AuditLogListResponse(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => AuditLogEntryModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  total: (json['total'] as num?)?.toInt() ?? 0,
);

AuditLogEntryModel _$AuditLogEntryModelFromJson(Map<String, dynamic> json) =>
    AuditLogEntryModel(
      id: (json['id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      userName: json['user_name'] as String?,
      action: json['action'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      field: json['field'] as String?,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      createdAt: json['created_at'] as String?,
    );

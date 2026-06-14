// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manager_dashboard_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagerDashboardModel _$ManagerDashboardModelFromJson(
  Map<String, dynamic> json,
) => ManagerDashboardModel(
  activeContracts: (json['active_contracts'] as num?)?.toInt() ?? 0,
  conditionalPlans: (json['conditional_plans'] as num?)?.toInt() ?? 0,
  openChefEscalations: (json['open_chef_escalations'] as num?)?.toInt() ?? 0,
  varianceCostImpact: json['variance_cost_impact'] == null
      ? 0
      : _toDouble(json['variance_cost_impact']),
  moneyHidden: json['money_hidden'] as bool? ?? false,
  hiddenFields:
      (json['hidden_fields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

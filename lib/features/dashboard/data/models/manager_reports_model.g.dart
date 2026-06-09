// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manager_reports_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagerPlanVsFactReport _$ManagerPlanVsFactReportFromJson(
  Map<String, dynamic> json,
) => ManagerPlanVsFactReport(
  items:
      (json['items'] as List<dynamic>?)
          ?.map(
            (e) => ManagerPlanVsFactItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  total: (json['total'] as num?)?.toInt() ?? 0,
);

ManagerPlanVsFactItem _$ManagerPlanVsFactItemFromJson(
  Map<String, dynamic> json,
) => ManagerPlanVsFactItem(
  plannedDate: json['planned_date'] as String?,
  plannedPortions: (json['planned_portions'] as num?)?.toInt() ?? 0,
  producedPortions: (json['produced_portions'] as num?)?.toInt() ?? 0,
  servedPortions: (json['served_portions'] as num?)?.toInt() ?? 0,
  leftoverPortions: (json['leftover_portions'] as num?)?.toInt() ?? 0,
  batches: (json['batches'] as num?)?.toInt() ?? 0,
);

ManagerCostPerHeadReport _$ManagerCostPerHeadReportFromJson(
  Map<String, dynamic> json,
) => ManagerCostPerHeadReport(
  items:
      (json['items'] as List<dynamic>?)
          ?.map(
            (e) => ManagerCostPerHeadItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  total: (json['total'] as num?)?.toInt() ?? 0,
  moneyHidden: json['money_hidden'] as bool? ?? false,
  hiddenFields:
      (json['hidden_fields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

ManagerCostPerHeadItem _$ManagerCostPerHeadItemFromJson(
  Map<String, dynamic> json,
) => ManagerCostPerHeadItem(
  serviceDate: json['service_date'] as String?,
  actualFoodCost: (json['actual_food_cost'] as num?)?.toDouble() ?? 0,
  mealsServed: (json['meals_served'] as num?)?.toInt() ?? 0,
  costPerHead: (json['cost_per_head'] as num?)?.toDouble() ?? 0,
);

ManagerVarianceBreakdownReport _$ManagerVarianceBreakdownReportFromJson(
  Map<String, dynamic> json,
) => ManagerVarianceBreakdownReport(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => ManagerVarianceItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  total: (json['total'] as num?)?.toInt() ?? 0,
  moneyHidden: json['money_hidden'] as bool? ?? false,
  hiddenFields:
      (json['hidden_fields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

ManagerVarianceItem _$ManagerVarianceItemFromJson(Map<String, dynamic> json) =>
    ManagerVarianceItem(
      category: json['category'] as String?,
      costImpact: (json['cost_impact'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      lossQty: (json['loss_qty'] as num?)?.toDouble() ?? 0,
    );

ManagerComplianceDigest _$ManagerComplianceDigestFromJson(
  Map<String, dynamic> json,
) => ManagerComplianceDigest(
  summary: json['summary'] == null
      ? null
      : ManagerComplianceSummary.fromJson(
          json['summary'] as Map<String, dynamic>,
        ),
);

ManagerComplianceSummary _$ManagerComplianceSummaryFromJson(
  Map<String, dynamic> json,
) => ManagerComplianceSummary(
  halalIssues: (json['halal_issues'] as num?)?.toInt() ?? 0,
  nutritionMissing: (json['nutrition_missing'] as num?)?.toInt() ?? 0,
  allergenMissing: (json['allergen_missing'] as num?)?.toInt() ?? 0,
);

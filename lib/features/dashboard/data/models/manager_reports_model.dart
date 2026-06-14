import 'package:json_annotation/json_annotation.dart';

part 'manager_reports_model.g.dart';

/// Бэкенд (Django `DecimalField`) присылает денежные поля строкой
/// (`"2798.0000"`), а не числом — парсим лояльно к обоим вариантам.
double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

/// План vs факт по дням (`GET /manager/reports/plan-vs-fact`).
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerPlanVsFactReport {
  const ManagerPlanVsFactReport({this.items = const [], this.total = 0});

  final List<ManagerPlanVsFactItem> items;
  final int total;

  factory ManagerPlanVsFactReport.fromJson(Map<String, dynamic> json) =>
      _$ManagerPlanVsFactReportFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerPlanVsFactItem {
  const ManagerPlanVsFactItem({
    this.plannedDate,
    this.plannedPortions = 0,
    this.producedPortions = 0,
    this.servedPortions = 0,
    this.leftoverPortions = 0,
    this.batches = 0,
  });

  final String? plannedDate;
  final int plannedPortions;
  final int producedPortions;
  final int servedPortions;
  final int leftoverPortions;
  final int batches;

  factory ManagerPlanVsFactItem.fromJson(Map<String, dynamic> json) =>
      _$ManagerPlanVsFactItemFromJson(json);
}

/// Себестоимость на человека (`GET /manager/reports/cost-per-head`).
/// Деньги могут быть скрыты по RBAC (`money_hidden`).
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerCostPerHeadReport {
  const ManagerCostPerHeadReport({
    this.items = const [],
    this.total = 0,
    this.moneyHidden = false,
    this.hiddenFields = const [],
  });

  final List<ManagerCostPerHeadItem> items;
  final int total;
  final bool moneyHidden;
  final List<String> hiddenFields;

  bool get showMoney => !moneyHidden;

  factory ManagerCostPerHeadReport.fromJson(Map<String, dynamic> json) =>
      _$ManagerCostPerHeadReportFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerCostPerHeadItem {
  const ManagerCostPerHeadItem({
    this.serviceDate,
    this.actualFoodCost = 0,
    this.mealsServed = 0,
    this.costPerHead = 0,
  });

  final String? serviceDate;
  @JsonKey(fromJson: _toDouble)
  final double actualFoodCost;
  final int mealsServed;
  @JsonKey(fromJson: _toDouble)
  final double costPerHead;

  factory ManagerCostPerHeadItem.fromJson(Map<String, dynamic> json) =>
      _$ManagerCostPerHeadItemFromJson(json);
}

/// Отклонения по категориям (`GET /manager/reports/variance-breakdown`).
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerVarianceBreakdownReport {
  const ManagerVarianceBreakdownReport({
    this.items = const [],
    this.total = 0,
    this.moneyHidden = false,
    this.hiddenFields = const [],
  });

  final List<ManagerVarianceItem> items;
  final int total;
  final bool moneyHidden;
  final List<String> hiddenFields;

  bool get showMoney => !moneyHidden;

  factory ManagerVarianceBreakdownReport.fromJson(Map<String, dynamic> json) =>
      _$ManagerVarianceBreakdownReportFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerVarianceItem {
  const ManagerVarianceItem({
    this.category,
    this.costImpact = 0,
    this.count = 0,
    this.lossQty = 0,
  });

  final String? category;
  @JsonKey(fromJson: _toDouble)
  final double costImpact;
  final int count;
  @JsonKey(fromJson: _toDouble)
  final double lossQty;

  factory ManagerVarianceItem.fromJson(Map<String, dynamic> json) =>
      _$ManagerVarianceItemFromJson(json);
}

/// Сводка соответствия (`GET /manager/digests/compliance`).
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerComplianceDigest {
  const ManagerComplianceDigest({this.summary});

  final ManagerComplianceSummary? summary;

  factory ManagerComplianceDigest.fromJson(Map<String, dynamic> json) =>
      _$ManagerComplianceDigestFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerComplianceSummary {
  const ManagerComplianceSummary({
    this.halalIssues = 0,
    this.nutritionMissing = 0,
    this.allergenMissing = 0,
  });

  final int halalIssues;
  final int nutritionMissing;
  final int allergenMissing;

  factory ManagerComplianceSummary.fromJson(Map<String, dynamic> json) =>
      _$ManagerComplianceSummaryFromJson(json);
}

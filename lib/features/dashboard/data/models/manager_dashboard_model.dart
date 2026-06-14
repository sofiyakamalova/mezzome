import 'package:json_annotation/json_annotation.dart';

part 'manager_dashboard_model.g.dart';

/// Бэкенд (Django `DecimalField`) присылает денежные поля строкой
/// (`"2798.0000"`), а не числом — парсим лояльно к обоим вариантам.
double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

/// Дашборд менеджера (`GET /manager/reports/dashboard`).
///
/// Операционные KPI: активные контракты, условно утверждённые планы и открытые
/// эскалации шефа. Денежное влияние отклонений (`variance_cost_impact`) бэкенд
/// может скрыть по RBAC — тогда приходит `money_hidden=true`, а само поле
/// перечислено в `hidden_fields`. UI показывает деньги только если
/// [showVarianceCost] истинно.
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ManagerDashboardModel {
  const ManagerDashboardModel({
    this.activeContracts = 0,
    this.conditionalPlans = 0,
    this.openChefEscalations = 0,
    this.varianceCostImpact = 0,
    this.moneyHidden = false,
    this.hiddenFields = const [],
  });

  /// Активные контракты ресторана.
  final int activeContracts;

  /// Условно утверждённые планы (требуют доведения до утверждения).
  final int conditionalPlans;

  /// Открытые эскалации от шефа (требуют реакции менеджера).
  final int openChefEscalations;

  /// Денежное влияние отклонений план/факт. Может быть скрыто по RBAC.
  @JsonKey(fromJson: _toDouble)
  final double varianceCostImpact;

  /// Бэкенд скрыл денежные показатели для этой роли.
  final bool moneyHidden;

  /// Список полей, скрытых по RBAC (например, `variance_cost_impact`).
  final List<String> hiddenFields;

  /// Показывать ли менеджеру денежное влияние отклонений.
  bool get showVarianceCost =>
      !moneyHidden && !hiddenFields.contains('variance_cost_impact');

  factory ManagerDashboardModel.fromJson(Map<String, dynamic> json) =>
      _$ManagerDashboardModelFromJson(json);
}

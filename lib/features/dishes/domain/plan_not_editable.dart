/// `PATCH /chef/production-plan-items/{id}` вернул `{"error":"PLAN_NOT_EDITABLE"}`.
///
/// Производство по ячейке уже началось — менять количество порций нельзя.
class PlanNotEditable implements Exception {
  const PlanNotEditable();

  /// Код ошибки, который шлёт backend.
  static const String code = 'PLAN_NOT_EDITABLE';

  @override
  String toString() => 'PlanNotEditable($code)';
}

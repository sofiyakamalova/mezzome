/// Production plans API returned 403 (e.g. `{"error":"FORBIDDEN"}`) for this role.
class ProductionPlanAccessDenied implements Exception {
  const ProductionPlanAccessDenied({this.apiError = 'FORBIDDEN'});

  final String apiError;

  @override
  String toString() => 'ProductionPlanAccessDenied($apiError)';
}

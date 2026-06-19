import 'package:mezzome/features/approvals/domain/behaviors/approvals_behavior.dart';

/// Принять/отклонить заявку (для отклонения причина обязательна на бэке).
class DecideApprovalUseCase {
  const DecideApprovalUseCase(this._behavior);

  final ApprovalsBehavior _behavior;

  Future<void> call({
    required Object id,
    required bool approve,
    required String reason,
  }) =>
      _behavior.decide(id: id, approve: approve, reason: reason);
}

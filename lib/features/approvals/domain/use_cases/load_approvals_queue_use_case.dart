import 'package:mezzome/features/approvals/domain/behaviors/approvals_behavior.dart';
import 'package:mezzome/features/approvals/domain/models/approval_item.dart';

/// Загрузить очередь согласования (все статусы; фильтрация — в bloc/state).
class LoadApprovalsQueueUseCase {
  const LoadApprovalsQueueUseCase(this._behavior);

  final ApprovalsBehavior _behavior;

  Future<List<ApprovalItem>> call() => _behavior.fetchQueue();
}

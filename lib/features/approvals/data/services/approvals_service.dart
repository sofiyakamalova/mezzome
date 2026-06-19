import 'package:mezzome/features/approvals/data/sources/approvals_remote_source.dart';
import 'package:mezzome/features/approvals/domain/behaviors/approvals_behavior.dart';
import 'package:mezzome/features/approvals/domain/models/approval_item.dart';

/// Реализация [ApprovalsBehavior]. Ошибки пробрасываются — маппит их bloc.
class ApprovalsService implements ApprovalsBehavior {
  const ApprovalsService(this._source);

  final ApprovalsRemoteSource _source;

  @override
  Future<List<ApprovalItem>> fetchQueue() => _source.fetchQueue();

  @override
  Future<void> decide({
    required Object id,
    required bool approve,
    required String reason,
  }) =>
      _source.decide(id: id, approve: approve, reason: reason);
}

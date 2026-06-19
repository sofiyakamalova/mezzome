import 'package:mezzome/features/approvals/domain/models/approval_item.dart';

/// Контракт очереди согласования техкарт.
abstract class ApprovalsBehavior {
  Future<List<ApprovalItem>> fetchQueue();
  Future<void> decide({
    required Object id,
    required bool approve,
    required String reason,
  });
}

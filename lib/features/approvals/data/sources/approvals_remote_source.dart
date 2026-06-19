import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/approvals/domain/models/approval_item.dart';

/// Сырой доступ к очереди согласования техкарт (Dio).
class ApprovalsRemoteSource {
  const ApprovalsRemoteSource(this._dio);

  final Dio _dio;

  /// Очередь `GET /manager/tk-approvals` (все статусы) → нормализованный список.
  Future<List<ApprovalItem>> fetchQueue() async {
    final res = await _dio.get<dynamic>('/manager/tk-approvals');
    appLogger.i('GET /manager/tk-approvals → 200');
    final data = res.data;
    final list = (data is Map && data['items'] is List)
        ? (data['items'] as List)
        : (data is List ? data : const []);
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map((m) {
          final statusStr =
              '${m['approval_status'] ?? m['status'] ?? ''}'.toLowerCase();
          final status = statusStr.contains('reject')
              ? ApprovalFilter.rejected
              : (statusStr.contains('approv')
                  ? ApprovalFilter.approved
                  : ApprovalFilter.pending);
          return ApprovalItem(
            id: m['id'] as int?,
            name: '${m['name'] ?? '—'}',
            code: '${m['code'] ?? ''}',
            version: m['version'] as int?,
            changeLevel: m['change_level'] as String?,
            submittedAt: DateTime.tryParse('${m['submitted_at'] ?? ''}'),
            status: status,
          );
        })
        .toList();
  }

  /// Решение по заявке: `POST /manager/tk-approvals/{id}/{approve|reject}`.
  Future<void> decide({
    required Object id,
    required bool approve,
    required String reason,
  }) async {
    final action = approve ? 'approve' : 'reject';
    final res = await _dio.post<dynamic>(
      '/manager/tk-approvals/$id/$action',
      data: <String, dynamic>{'reason': reason, 'comment': reason},
    );
    appLogger.i('POST /manager/tk-approvals/$id/$action → ${res.statusCode}');
  }
}

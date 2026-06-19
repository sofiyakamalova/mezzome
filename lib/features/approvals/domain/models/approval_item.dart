/// Вкладка-фильтр очереди согласования техкарт.
enum ApprovalFilter { pending, approved, rejected }

/// Нормализованная заявка на согласование (из `tk-approvals`).
class ApprovalItem {
  const ApprovalItem({
    this.id,
    this.name = '—',
    this.code = '',
    this.version,
    this.changeLevel,
    this.submittedAt,
    required this.status,
  });

  final int? id;
  final String name;
  final String code;
  final int? version;
  final String? changeLevel;
  final DateTime? submittedAt;
  final ApprovalFilter status;
}

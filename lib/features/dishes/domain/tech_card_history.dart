import 'package:mezzome/features/dishes/domain/journal_entry.dart';

/// Результат загрузки истории техкарты для UI.
class TechCardHistoryResult {
  const TechCardHistoryResult({
    this.entries = const [],
    this.forbidden = false,
  });

  final List<TechCardHistoryEntry> entries;

  /// Роут chef-only вернул 403 — у текущей роли нет доступа к истории.
  final bool forbidden;
}

/// Одна запись истории техкарты (`GET /chef/technical-cards/{id}/history`).
///
/// Форма ответа (подтверждена бэкендом 2026-06-05):
/// ```json
/// { "history": [ {
///     "id": 992203, "technical_card_id": 992003, "root_id": 992001,
///     "from_version": 1, "to_version": 2, "change_level": "PARAMETRIC",
///     "requires_approval": true,
///     "diff": { "base_portions": {"from":100,"to":50}, "name": {...},
///               "action": "...", "fields": [...],
///               "signature": {"signed_by_name":"...","signed_at":"..."} },
///     "created_by": 990105, "created_at": "2026-06-04T14:42:59Z"
/// } ], "total": 2 }
/// ```
class TechCardHistoryEntry {
  const TechCardHistoryEntry({
    this.id,
    this.fromVersion,
    this.toVersion,
    this.changeLevel,
    this.requiresApproval = false,
    this.authorName,
    this.authorId,
    this.timestamp,
    this.action,
    this.changedFields = const [],
    this.changes = const [],
  });

  final int? id;

  /// Версия-источник (`from_version`) и результирующая (`to_version`).
  final int? fromVersion;
  final int? toVersion;

  /// Уровень изменения (`change_level`): COSMETIC / PARAMETRIC / STRUCTURAL.
  final String? changeLevel;

  /// Требует ли версия согласования (`requires_approval`).
  final bool requiresApproval;

  /// Имя автора — только из `diff.signature.signed_by_name` (если есть).
  final String? authorName;

  /// Id автора (`created_by`, в подписи — `signed_by_user_id`).
  final int? authorId;

  /// Когда (`created_at`, fallback — `diff.signature.signed_at`).
  final DateTime? timestamp;

  /// Системное действие из `diff.action` (напр. `initial_week_grid_seed`).
  final String? action;

  /// Имена изменённых полей без значений (`diff.fields`).
  final List<String> changedFields;

  /// Построчный diff `{поле: {from, to}}` → было → стало.
  final List<JournalFieldChange> changes;

  /// Подпись автора для UI: имя, иначе `ID <authorId>`, иначе null.
  String? get authorLabel {
    if (authorName != null && authorName!.trim().isNotEmpty) {
      return authorName;
    }
    if (authorId != null) {
      return 'ID $authorId';
    }
    return null;
  }

  static TechCardHistoryEntry? _tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = raw.map((k, v) => MapEntry('$k', v));

    int? asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime? asDate(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    final diff = _Diff.parse(map['diff']);

    return TechCardHistoryEntry(
      id: asInt(map['id']),
      fromVersion: asInt(map['from_version']),
      toVersion: asInt(map['to_version']),
      changeLevel: map['change_level'] is String
          ? map['change_level'] as String
          : null,
      requiresApproval: map['requires_approval'] == true,
      authorName: diff.signedByName,
      authorId: asInt(map['created_by']) ?? diff.signedByUserId,
      timestamp: asDate(map['created_at']) ?? diff.signedAt,
      action: diff.action,
      changedFields: diff.fields,
      changes: diff.changes,
    );
  }
}

/// Разбор объекта `diff`: разделяет спец-ключи (`action`/`fields`/`signature`)
/// и обычные изменения полей `{поле: {from, to}}`.
class _Diff {
  const _Diff({
    this.action,
    this.fields = const [],
    this.changes = const [],
    this.signedByName,
    this.signedByUserId,
    this.signedAt,
  });

  final String? action;
  final List<String> fields;
  final List<JournalFieldChange> changes;
  final String? signedByName;
  final int? signedByUserId;
  final DateTime? signedAt;

  static _Diff parse(Object? raw) {
    if (raw is! Map) {
      return const _Diff();
    }
    String? action;
    var fields = <String>[];
    final changes = <JournalFieldChange>[];
    String? signedByName;
    int? signedByUserId;
    DateTime? signedAt;

    raw.forEach((key, value) {
      final k = '$key';
      switch (k) {
        case 'action':
          if (value is String) action = value;
        case 'fields':
          if (value is List) {
            fields = value.map((e) => '$e').toList();
          }
        case 'signature':
          if (value is Map) {
            final sig = value.map((sk, sv) => MapEntry('$sk', sv));
            final name = sig['signed_by_name'];
            if (name is String && name.trim().isNotEmpty) signedByName = name;
            final uid = sig['signed_by_user_id'];
            if (uid is num) signedByUserId = uid.toInt();
            final at = sig['signed_at'];
            if (at is String) signedAt = DateTime.tryParse(at);
          }
        default:
          // Обычное изменение поля: { "from": ..., "to": ... }.
          if (value is Map) {
            final m = value.map((vk, vv) => MapEntry('$vk', vv));
            if (m.containsKey('from') || m.containsKey('to')) {
              changes.add(
                JournalFieldChange(
                  field: k,
                  oldValue: '${m['from'] ?? ''}',
                  newValue: '${m['to'] ?? ''}',
                ),
              );
            }
          }
      }
    });

    return _Diff(
      action: action,
      fields: fields,
      changes: changes,
      signedByName: signedByName,
      signedByUserId: signedByUserId,
      signedAt: signedAt,
    );
  }
}

/// Достаёт и сортирует записи истории из ответа `/history`
/// (объект со списком под ключом `history`; новые версии — сверху).
List<TechCardHistoryEntry> parseTechCardHistory(Object? raw) {
  List? list;
  if (raw is List) {
    list = raw;
  } else if (raw is Map) {
    final value = raw['history'] ?? raw['versions'] ?? raw['items'];
    if (value is List) list = value;
  }
  if (list == null) {
    return const [];
  }
  final entries = <TechCardHistoryEntry>[];
  for (final item in list) {
    final parsed = TechCardHistoryEntry._tryParse(item);
    if (parsed != null) entries.add(parsed);
  }
  entries.sort((a, b) {
    final byVersion = (b.toVersion ?? 0).compareTo(a.toVersion ?? 0);
    if (byVersion != 0) return byVersion;
    final at = a.timestamp, bt = b.timestamp;
    if (at != null && bt != null) return bt.compareTo(at);
    return 0;
  });
  return entries;
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.timestamp,
    required this.signature,
    required this.summary,
    this.cellKey,
    this.fieldChanges = const [],
  });

  final String id;
  final DateTime timestamp;
  final String signature;
  final String summary;
  final String? cellKey;
  final List<JournalFieldChange> fieldChanges;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'signature': signature,
        'summary': summary,
        'cell_key': cellKey,
        'field_changes': fieldChanges.map((e) => e.toJson()).toList(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      signature: json['signature'] as String,
      summary: json['summary'] as String,
      cellKey: json['cell_key'] as String?,
      fieldChanges: (json['field_changes'] as List<dynamic>? ?? [])
          .map((e) => JournalFieldChange.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class JournalFieldChange {
  const JournalFieldChange({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  final String field;
  final String oldValue;
  final String newValue;

  Map<String, dynamic> toJson() => {
        'field': field,
        'old_value': oldValue,
        'new_value': newValue,
      };

  factory JournalFieldChange.fromJson(Map<String, dynamic> json) {
    return JournalFieldChange(
      field: json['field'] as String,
      oldValue: json['old_value'] as String? ?? '',
      newValue: json['new_value'] as String? ?? '',
    );
  }
}

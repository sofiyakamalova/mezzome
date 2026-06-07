import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/features/dishes/domain/journal_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _journalKey = 'menu_dashboard_journal_v1';
const _modifiedCellsKey = 'menu_dashboard_modified_cells_v1';

class MenuJournalStorage {
  MenuJournalStorage(this._prefs);

  final SharedPreferences _prefs;

  List<JournalEntry> loadJournal() {
    final raw = _prefs.getString(_journalKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  Future<void> appendEntry(JournalEntry entry) async {
    final entries = loadJournal()..add(entry);
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _prefs.setString(
      _journalKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Set<String> loadModifiedCellKeys() {
    final raw = _prefs.getStringList(_modifiedCellsKey);
    return raw?.toSet() ?? {};
  }

  Future<void> saveModifiedCellKeys(Set<String> keys) async {
    await _prefs.setStringList(_modifiedCellsKey, keys.toList());
  }
}

final menuJournalStorageProvider = Provider<MenuJournalStorage>((ref) {
  throw UnimplementedError('Override in main.dart');
});

Future<MenuJournalStorage> createMenuJournalStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return MenuJournalStorage(prefs);
}

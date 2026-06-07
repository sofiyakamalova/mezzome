import 'package:mezzome/features/dishes/domain/journal_entry.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';

class MenuDashboardState {
  const MenuDashboardState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.selectedService = MenuServiceType.breakfast,
    this.weekDays = const [],
    this.rows = const [],
    this.consumptionByDay = const {},
    this.selectedCellKey,
    this.editorDraft,
    this.editorOriginal,
    this.journalEntries = const [],
    this.modifiedCellKeys = const {},
    this.positionCount = 0,
    this.weeklyCost = 0,
    this.searchQuery = '',
    this.errorMessage,
    this.techCardLoadNotice,
  });

  final bool isLoading;
  final bool isRefreshing;
  final MenuServiceType selectedService;
  final List<DateTime> weekDays;
  final List<MenuGridRow> rows;
  final Map<int, double> consumptionByDay;
  final String? selectedCellKey;
  final TechCardDraft? editorDraft;
  final TechCardDraft? editorOriginal;
  final List<JournalEntry> journalEntries;
  final Set<String> modifiedCellKeys;
  final int positionCount;
  final double weeklyCost;
  final String searchQuery;
  final String? errorMessage;
  /// Shown once when editor opens without full technical-card detail (e.g. HTTP 500).
  final String? techCardLoadNotice;

  int get changedCount => modifiedCellKeys.length;

  MenuGridCell? get selectedCell {
    if (selectedCellKey == null) {
      return null;
    }
    for (final row in rows) {
      for (final cell in row.cellsByDayIndex.values) {
        if (cell.cellKey == selectedCellKey) {
          return cell;
        }
      }
    }
    return null;
  }

  List<MenuGridRow> get filteredRows {
    if (searchQuery.trim().isEmpty) {
      return rows;
    }
    final q = searchQuery.trim().toLowerCase();
    return rows
        .where(
          (row) =>
              row.label.toLowerCase().contains(q) ||
              row.cellsByDayIndex.values
                  .any((cell) => cell.dishName.toLowerCase().contains(q)),
        )
        .toList();
  }

  MenuDashboardState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    MenuServiceType? selectedService,
    List<DateTime>? weekDays,
    List<MenuGridRow>? rows,
    Map<int, double>? consumptionByDay,
    String? selectedCellKey,
    TechCardDraft? editorDraft,
    TechCardDraft? editorOriginal,
    List<JournalEntry>? journalEntries,
    Set<String>? modifiedCellKeys,
    int? positionCount,
    double? weeklyCost,
    String? searchQuery,
    String? errorMessage,
    String? techCardLoadNotice,
    bool clearSelectedCell = false,
    bool clearEditor = false,
    bool clearError = false,
    bool clearTechCardLoadNotice = false,
  }) {
    return MenuDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      selectedService: selectedService ?? this.selectedService,
      weekDays: weekDays ?? this.weekDays,
      rows: rows ?? this.rows,
      consumptionByDay: consumptionByDay ?? this.consumptionByDay,
      selectedCellKey:
          clearSelectedCell ? null : (selectedCellKey ?? this.selectedCellKey),
      editorDraft: clearEditor ? null : (editorDraft ?? this.editorDraft),
      editorOriginal:
          clearEditor ? null : (editorOriginal ?? this.editorOriginal),
      journalEntries: journalEntries ?? this.journalEntries,
      modifiedCellKeys: modifiedCellKeys ?? this.modifiedCellKeys,
      positionCount: positionCount ?? this.positionCount,
      weeklyCost: weeklyCost ?? this.weeklyCost,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      techCardLoadNotice: clearTechCardLoadNotice
          ? null
          : (techCardLoadNotice ?? this.techCardLoadNotice),
    );
  }
}

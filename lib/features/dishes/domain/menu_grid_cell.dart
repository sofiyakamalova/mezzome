import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';

/// One active cell in the weekly menu grid.
class MenuGridCell {
  const MenuGridCell({
    required this.rowKey,
    required this.rowLabel,
    required this.date,
    this.menuItemId,
    this.dishName = '',
    this.plannedPortions,
    this.costPerPortion,
    this.technicalCardId,
    this.planItemId,
    this.planStatus,
    this.technicalCardVersion,
    this.isModified = false,
    this.techCardDraft,
  });

  final String rowKey;
  final String rowLabel;
  final DateTime date;
  final int? menuItemId;
  final String dishName;
  final int? plannedPortions;
  final double? costPerPortion;
  final int? technicalCardId;

  /// `plan_item_id` — id строки плана; нужен для PATCH planned_portions.
  final int? planItemId;

  /// Статус плана ячейки (`draft` / `approved` / `in_production` / ...).
  final String? planStatus;

  /// Номер версии техкарты ячейки (`technical_card_version`).
  final int? technicalCardVersion;
  final bool isModified;
  final TechCardDraft? techCardDraft;

  String get cellKey =>
      '$rowKey|${date.year}-${date.month}-${date.day}';

  /// No production-plan line for this dish on this day.
  bool get isEmpty => menuItemId == null || (plannedPortions ?? 0) <= 0;

  MenuGridCell copyWith({
    String? rowKey,
    String? rowLabel,
    DateTime? date,
    int? menuItemId,
    String? dishName,
    int? plannedPortions,
    double? costPerPortion,
    int? technicalCardId,
    int? planItemId,
    String? planStatus,
    int? technicalCardVersion,
    bool? isModified,
    TechCardDraft? techCardDraft,
    bool clearTechCardDraft = false,
  }) {
    return MenuGridCell(
      rowKey: rowKey ?? this.rowKey,
      rowLabel: rowLabel ?? this.rowLabel,
      date: date ?? this.date,
      menuItemId: menuItemId ?? this.menuItemId,
      dishName: dishName ?? this.dishName,
      plannedPortions: plannedPortions ?? this.plannedPortions,
      costPerPortion: costPerPortion ?? this.costPerPortion,
      technicalCardId: technicalCardId ?? this.technicalCardId,
      planItemId: planItemId ?? this.planItemId,
      planStatus: planStatus ?? this.planStatus,
      technicalCardVersion: technicalCardVersion ?? this.technicalCardVersion,
      isModified: isModified ?? this.isModified,
      techCardDraft: clearTechCardDraft
          ? null
          : (techCardDraft ?? this.techCardDraft),
    );
  }
}

class MenuGridRow {
  const MenuGridRow({
    required this.key,
    required this.label,
    required this.cellsByDayIndex,
  });

  final String key;
  final String label;
  final Map<int, MenuGridCell> cellsByDayIndex;
}

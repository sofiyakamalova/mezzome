import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/di/session_holder.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/local/menu_journal_storage.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';
import 'package:mezzome/features/dishes/domain/journal_entry.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/domain/plan_not_editable.dart';
import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';
import 'package:mezzome/features/dishes/presentation/providers/menu_dashboard_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

export 'package:mezzome/features/dishes/presentation/providers/menu_dashboard_state.dart';

/// Меню-борд + редактор техкарт. Контроллер запрос-ответ (методы возвращают
/// [SaveResult] и мутируют draft), поэтому Cubit, а не event-Bloc. Singleton в
/// get_it — общий инстанс для dishes и approvals (как прежний глобальный
/// Riverpod-провайдер). Роль/имя берём из SessionHolder.
class MenuDashboardCubit extends Cubit<MenuDashboardState> {
  MenuDashboardCubit(this._repo, this._session)
      : super(const MenuDashboardState()) {
    _initJournalStorage();
  }

  final MenuDashboardRepository _repo;
  final SessionHolder _session;

  MenuJournalStorage? _journalStorage;
  DateTime? _anchorDate;

  Future<void> _initJournalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _journalStorage = MenuJournalStorage(prefs);
    emit(state.copyWith(
      journalEntries: _journalStorage!.loadJournal(),
      modifiedCellKeys: _journalStorage!.loadModifiedCellKeys(),
    ));
  }

  Future<void> loadForDate(DateTime anchor, {bool refresh = false}) async {
    final normalized = DateFormatUtil.normalizeScheduleDate(anchor);
    if (!refresh &&
        _anchorDate != null &&
        DateFormatUtil.isSameDay(_anchorDate!, normalized) &&
        !state.isLoading &&
        state.rows.isNotEmpty) {
      return;
    }
    _anchorDate = normalized;

    emit(state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
    ));

    try {
      final weekDays = _repo.gridDaysForSelectedDate(normalized);
      final service = state.selectedService;
      appLogger.i(
        'Menu grid: ${DateFormatUtil.apiDate(normalized)}, '
        'service=${service.apiValue}',
      );
      final week = await _repo.fetchDaySchedule(normalized, service: service);
      final consumption = _repo.consumptionByDayIndex(week, service);
      final rows = _buildRows(week, weekDays, service, state.modifiedCellKeys);
      final serviceItems = _repo.itemsForService(week, service);
      final weeklyCost = serviceItems.fold<double>(
        0,
        (sum, item) => sum + (item.theoreticalCost ?? 0),
      );

      emit(state.copyWith(
        isLoading: false,
        isRefreshing: false,
        weekDays: weekDays,
        rows: rows,
        consumptionByDay: consumption,
        positionCount: rows.length,
        weeklyCost: weeklyCost,
      ));
    } catch (error, stack) {
      appLogger.e('Menu dashboard load failed', error: error, stackTrace: stack);
      emit(state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'menuDashboardLoadError'.tr(),
      ));
    }
  }

  List<MenuGridRow> _buildRows(
    List<WeekScheduleDay> week,
    List<DateTime> weekDays,
    MenuServiceType service,
    Set<String> modifiedKeys,
  ) {
    final rowKeys = <String>{};
    final itemsByRow = <String, ScheduledMenuItem>{};

    for (final day in week) {
      for (final item in day.items) {
        if (!service.matchesApiValue(item.serviceType)) continue;
        final key = 'dish_${item.menuItemId}';
        rowKeys.add(key);
        itemsByRow.putIfAbsent(key, () => item);
      }
    }

    if (rowKeys.isEmpty) {
      for (final day in week) {
        for (final item in day.items) {
          final key = 'dish_${item.menuItemId}';
          rowKeys.add(key);
          itemsByRow.putIfAbsent(key, () => item);
        }
      }
    }

    final sortedKeys = rowKeys.toList()
      ..sort((a, b) =>
          (itemsByRow[a]?.name ?? a).compareTo(itemsByRow[b]?.name ?? b));

    return sortedKeys.map((rowKey) {
      final label = itemsByRow[rowKey]?.name ?? rowKey;
      final cells = <int, MenuGridCell>{};
      for (var dayIndex = 0; dayIndex < weekDays.length; dayIndex++) {
        final date = weekDays[dayIndex];
        final dayItems = week[dayIndex].items;
        ScheduledMenuItem? match;
        for (final item in dayItems) {
          if ('dish_${item.menuItemId}' == rowKey &&
              service.matchesApiValue(item.serviceType)) {
            match = item;
            break;
          }
        }
        final cellKey = '$rowKey|${date.year}-${date.month}-${date.day}';
        final portions = match?.plannedPortions ?? 0;
        final totalCost = match?.theoreticalCost;
        final costPerPortion =
            portions > 0 && totalCost != null ? totalCost / portions : null;
        cells[dayIndex] = MenuGridCell(
          rowKey: rowKey,
          rowLabel: label,
          date: date,
          menuItemId: match?.menuItemId,
          dishName: match?.name ?? label,
          plannedPortions: portions > 0 ? portions : null,
          costPerPortion: costPerPortion,
          technicalCardId: match?.technicalCardId,
          planItemId: match?.planItemId,
          planStatus: match?.planStatus,
          isModified: modifiedKeys.contains(cellKey),
        );
      }
      return MenuGridRow(key: rowKey, label: label, cellsByDayIndex: cells);
    }).toList();
  }

  Future<void> selectService(MenuServiceType service) async {
    if (state.selectedService == service) return;
    emit(state.copyWith(
      selectedService: service,
      clearSelectedCell: true,
      clearEditor: true,
    ));
    if (_anchorDate != null) {
      await loadForDate(_anchorDate!, refresh: true);
    }
  }

  void setSearchQuery(String query) =>
      emit(state.copyWith(searchQuery: query));

  Future<void> selectCell(
    MenuGridCell cell, {
    bool requestContext = false,
  }) async {
    emit(state.copyWith(selectedCellKey: cell.cellKey, clearEditor: true));

    final serviceLabel = state.selectedService.label;
    final dayLabel = DateFormatUtil.formatDisplayDate(cell.date, 'ru');

    TechnicalCardModel? card;
    if (cell.technicalCardId != null) {
      card = await _repo.loadTechnicalCardFull(cell.technicalCardId!);
    }
    if (card == null && cell.menuItemId != null) {
      card = await _repo.findTechnicalCardByMenuItem(cell.menuItemId!);
    }
    card ??= await _repo.findTechnicalCardByName(cell.dishName);
    final detailUnavailable = card != null && card.ingredients.isEmpty;

    TechCardDraft draft;
    if (card != null) {
      draft = _repo.draftFromTechnicalCard(
        card,
        serviceLabel: serviceLabel,
        dayLabel: dayLabel,
        categoryLabel: cell.rowLabel,
        scheduleless: requestContext,
        plannedPortions: requestContext ? null : cell.plannedPortions,
        planItemId: requestContext ? null : cell.planItemId,
        menuItemId: cell.menuItemId,
      );
    } else if (cell.menuItemId != null) {
      draft = _repo.draftFromScheduledItem(
        ScheduledMenuItem(
          menuItemId: cell.menuItemId!,
          name: cell.dishName,
          plannedPortions: cell.plannedPortions ?? 1,
          serviceType: state.selectedService.name,
          planStatus: '—',
          planItemId: requestContext ? null : cell.planItemId,
          theoreticalCost:
              cell.costPerPortion != null && cell.plannedPortions != null
                  ? cell.costPerPortion! * cell.plannedPortions!
                  : null,
        ),
        serviceLabel: serviceLabel,
        dayLabel: dayLabel,
      );
    } else {
      draft = TechCardDraft(
        name: cell.dishName,
        serviceLabel: serviceLabel,
        dayLabel: dayLabel,
        categoryLabel: cell.rowLabel,
      )..originalSnapshot = TechCardDraft(
          name: cell.dishName,
          serviceLabel: serviceLabel,
          dayLabel: dayLabel,
          categoryLabel: cell.rowLabel,
        ).copyForSnapshot();
    }

    emit(state.copyWith(
      editorDraft: draft,
      editorOriginal: draft.originalSnapshot,
      selectedCellKey: cell.cellKey,
      techCardLoadNotice:
          detailUnavailable ? 'techCardDetailUnavailable'.tr() : null,
      clearTechCardLoadNotice: !detailUnavailable,
    ));
  }

  void clearTechCardLoadNotice() =>
      emit(state.copyWith(clearTechCardLoadNotice: true));

  void closeEditor() => emit(state.copyWith(
        clearSelectedCell: true,
        clearEditor: true,
        clearTechCardLoadNotice: true,
      ));

  void updateEditorDraft(TechCardDraft draft) =>
      emit(state.copyWith(editorDraft: draft));

  void rollbackEditor() {
    final original = state.editorOriginal;
    if (original == null) return;
    final restored = original.copyForSnapshot();
    restored.originalSnapshot = original;
    emit(state.copyWith(editorDraft: restored));
  }

  Future<SaveResult> pullDishIngredients() async {
    final draft = state.editorDraft;
    if (draft == null || draft.menuItemId == null) {
      return SaveResult(error: 'dishIngredientsError'.tr());
    }
    try {
      final ingredients = await _repo.loadDishIngredients(draft.menuItemId!);
      if (ingredients.isEmpty) {
        return SaveResult(notice: 'dishIngredientsEmpty'.tr());
      }
      draft.ingredients = ingredients;
      emit(state.copyWith(editorDraft: draft));
      final preparations =
          ingredients.where((e) => e.ingredientId == null).length;
      if (preparations > 0) {
        return SaveResult(
          notice: 'dishIngredientsPreparationsNotice'
              .tr(namedArgs: {'count': '$preparations'}),
        );
      }
      return SaveResult(
        notice: 'dishIngredientsPulled'
            .tr(namedArgs: {'count': '${ingredients.length}'}),
      );
    } on DioException catch (error) {
      appLogger.w('Pull dish ingredients failed: ${error.message}');
      return SaveResult(error: 'dishIngredientsError'.tr());
    }
  }

  Future<SaveResult> saveAndSign() async {
    final draft = state.editorDraft;
    final cellKey = state.selectedCellKey;
    if (draft == null || cellKey == null) {
      appLogger.w('saveAndSign: nothing to save');
      return const SaveResult();
    }

    final session = _session.user;
    final signature =
        session == null ? 'MEZZOME' : '${session.name} | MEZZOME';

    final original = state.editorOriginal ?? draft.copyForSnapshot();
    final changes = draft.diffFrom(original);
    final isChef = session?.role == UserRole.chef;

    if (!draft.readOnly && !draft.massConverges()) {
      final pct = draft.massDivergencePct ?? 0;
      appLogger.w('saveAndSign: blocked — mass divergence ${pct.toStringAsFixed(1)}%');
      return SaveResult(
        error: 'tcpMassBlock'.tr(namedArgs: {'pct': pct.toStringAsFixed(1)}),
      );
    }

    if (!isChef && changes.isNotEmpty && draft.editReason.trim().isEmpty) {
      appLogger.w('saveAndSign: blocked — edit reason required');
      return SaveResult(error: 'tcpReasonRequired'.tr());
    }

    try {
      if (draft.id != null) {
        final validationKey = draft.validationErrorKey();
        if (validationKey != null) {
          appLogger.w('saveAndSign: rejected by client validation: $validationKey');
          return SaveResult(error: validationKey.tr());
        }
        appLogger.i('saveAndSign: PATCH technical-card ${draft.id}…');
        final saved = await _repo.saveTechnicalCard(
          id: draft.id!,
          draft: draft,
          submitForApproval: !isChef,
        );
        if (isChef) {
          final approveId = saved?.id ?? draft.id!;
          await _repo.approveTechnicalCard(approveId);
        }
      } else {
        appLogger.w('saveAndSign: draft has no card id — local journal only');
      }
    } on DioException catch (error) {
      if (error.response != null) {
        appLogger.w('Tech card save rejected: ${error.response?.data}');
        return SaveResult(
          error: apiErrorDetails(error) ?? 'techCardSaveError'.tr(),
        );
      }
      appLogger.w('API save failed (network) — persisting locally');
    } catch (_) {
      appLogger.w('API save failed — persisting locally with journal entry');
    }

    String? notice;
    final newPortions = draft.plannedPortions;
    final portionsChanged =
        newPortions != null && newPortions != original.plannedPortions;
    if (portionsChanged && draft.planItemId != null) {
      try {
        await _repo.updatePlannedPortions(
          planItemId: draft.planItemId!,
          asManager: session?.role == UserRole.manager,
          plannedPortions: newPortions,
        );
        notice = 'planResetToDraftNotice'.tr();
      } on PlanNotEditable {
        draft.plannedPortions = original.plannedPortions;
        emit(state.copyWith(editorDraft: draft));
        return SaveResult(error: 'planNotEditableError'.tr());
      } catch (error) {
        appLogger.w('Planned portions update failed: $error');
      }
    }

    final summaryParts = <String>[];
    if (changes.any((c) => c.field == 'name')) {
      final nameChange = changes.firstWhere((c) => c.field == 'name');
      summaryParts.add('${nameChange.oldValue} → ${nameChange.newValue}');
    }
    ({String field, String oldValue, String newValue})? costChange;
    for (final change in changes) {
      if (change.field == 'portionCost') {
        costChange = change;
        break;
      }
    }
    if (costChange != null) {
      summaryParts.add('cost ${costChange.oldValue} → ${costChange.newValue} ₸');
    }
    if (changes.any((c) => c.field == 'ingredients')) {
      final ing = changes.firstWhere((c) => c.field == 'ingredients');
      summaryParts.add('ingredients ${ing.oldValue} → ${ing.newValue}');
    }

    final entry = JournalEntry(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      signature: signature,
      summary: summaryParts.isEmpty
          ? 'techCardSaved'.tr(namedArgs: {'name': draft.name})
          : summaryParts.join('; '),
      cellKey: cellKey,
      fieldChanges: changes
          .map((c) => JournalFieldChange(
                field: c.field,
                oldValue: c.oldValue,
                newValue: c.newValue,
              ))
          .toList(),
    );

    await _journalStorage?.appendEntry(entry);
    final modified = {...state.modifiedCellKeys, cellKey};
    await _journalStorage?.saveModifiedCellKeys(modified);

    final updatedRows = _applyCellChanges(
      state.rows,
      cellKey,
      cost: draft.portionCost,
      plannedPortions: portionsChanged ? newPortions : null,
    );
    emit(state.copyWith(
      journalEntries: [entry, ...state.journalEntries],
      modifiedCellKeys: modified,
      rows: updatedRows,
      editorOriginal: draft.copyForSnapshot(),
    ));

    if (_anchorDate != null) {
      loadForDate(_anchorDate!, refresh: true).ignore();
    }

    return SaveResult(notice: notice);
  }

  List<MenuGridRow> _applyCellChanges(
    List<MenuGridRow> rows,
    String cellKey, {
    required double cost,
    int? plannedPortions,
  }) {
    return rows.map((row) {
      final updatedCells = row.cellsByDayIndex.map((index, cell) {
        if (cell.cellKey != cellKey) return MapEntry(index, cell);
        return MapEntry(
          index,
          cell.copyWith(
            costPerPortion: cost,
            dishName: state.editorDraft?.name ?? cell.dishName,
            plannedPortions: plannedPortions,
            isModified: true,
          ),
        );
      });
      return MenuGridRow(
        key: row.key,
        label: row.label,
        cellsByDayIndex: updatedCells,
      );
    }).toList();
  }

  Future<void> revertCell(String cellKey) async {
    final modified = {...state.modifiedCellKeys}..remove(cellKey);
    await _journalStorage?.saveModifiedCellKeys(modified);
    if (_anchorDate != null) {
      emit(state.copyWith(modifiedCellKeys: modified));
      await loadForDate(_anchorDate!, refresh: true);
    }
  }
}

/// Итог [MenuDashboardCubit.saveAndSign] для UI.
class SaveResult {
  const SaveResult({this.error, this.notice});

  /// Блокирующая ошибка — редактор не закрывать, показать пользователю.
  final String? error;

  /// Информационное уведомление (например, план сброшен в draft).
  final String? notice;
}

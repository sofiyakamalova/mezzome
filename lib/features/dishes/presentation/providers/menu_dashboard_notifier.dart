import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
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

class MenuDashboardNotifier extends Notifier<MenuDashboardState> {
  MenuJournalStorage? _journalStorage;
  DateTime? _anchorDate;

  @override
  MenuDashboardState build() {
    _initJournalStorage();
    return const MenuDashboardState();
  }

  Future<void> _initJournalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _journalStorage = MenuJournalStorage(prefs);
    final journal = _journalStorage!.loadJournal();
    final modified = _journalStorage!.loadModifiedCellKeys();
    state = state.copyWith(
      journalEntries: journal,
      modifiedCellKeys: modified,
    );
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

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
    );

    try {
      final repo = ref.read(menuDashboardRepositoryProvider);
      final weekDays = repo.gridDaysForSelectedDate(normalized);
      final service = state.selectedService;
      appLogger.i(
        'Menu grid: ${DateFormatUtil.apiDate(normalized)}, '
        'service=${service.apiValue}',
      );
      final week = await repo.fetchDaySchedule(
        normalized,
        service: service,
      );
      final consumption = repo.consumptionByDayIndex(week, service);
      final rows = _buildRows(week, weekDays, service, state.modifiedCellKeys);
      final serviceItems = repo.itemsForService(week, service);
      final weeklyCost = serviceItems.fold<double>(
        0,
        (sum, item) => sum + (item.theoreticalCost ?? 0),
      );

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        weekDays: weekDays,
        rows: rows,
        consumptionByDay: consumption,
        positionCount: rows.length,
        weeklyCost: weeklyCost,
      );
    } catch (error, stack) {
      appLogger.e('Menu dashboard load failed', error: error, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'menuDashboardLoadError'.tr(),
      );
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
        if (!service.matchesApiValue(item.serviceType)) {
          continue;
        }
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
      ..sort((a, b) => (itemsByRow[a]?.name ?? a)
          .compareTo(itemsByRow[b]?.name ?? b));

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
        final costPerPortion = portions > 0 && totalCost != null
            ? totalCost / portions
            : null;
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
    if (state.selectedService == service) {
      return;
    }
    state = state.copyWith(
      selectedService: service,
      clearSelectedCell: true,
      clearEditor: true,
    );
    if (_anchorDate != null) {
      await loadForDate(_anchorDate!, refresh: true);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> selectCell(MenuGridCell cell, {bool requestContext = false}) async {
    state = state.copyWith(
      selectedCellKey: cell.cellKey,
      clearEditor: true,
    );

    final repo = ref.read(menuDashboardRepositoryProvider);
    final serviceLabel = state.selectedService.label;
    final dayLabel = DateFormatUtil.formatDisplayDate(
      cell.date,
      'ru',
    );

    TechnicalCardModel? card;
    if (cell.technicalCardId != null) {
      card = await repo.loadTechnicalCardFull(cell.technicalCardId!);
    }
    // Grid пока не отдаёт technical_card_id — резолвим карту по menu_item_id,
    // затем фолбэк по имени блюда.
    if (card == null && cell.menuItemId != null) {
      card = await repo.findTechnicalCardByMenuItem(cell.menuItemId!);
    }
    card ??= await repo.findTechnicalCardByName(cell.dishName);
    // Карта найдена, но без состава (detail с сервера недоступен).
    final detailUnavailable = card != null && card.ingredients.isEmpty;

    TechCardDraft draft;
    if (card != null) {
      draft = repo.draftFromTechnicalCard(
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
      draft = repo.draftFromScheduledItem(
        ScheduledMenuItem(
          menuItemId: cell.menuItemId!,
          name: cell.dishName,
          plannedPortions: cell.plannedPortions ?? 1,
          serviceType: state.selectedService.name,
          planStatus: '—',
          planItemId: requestContext ? null : cell.planItemId,
          theoreticalCost: cell.costPerPortion != null && cell.plannedPortions != null
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

    state = state.copyWith(
      editorDraft: draft,
      editorOriginal: draft.originalSnapshot,
      selectedCellKey: cell.cellKey,
      techCardLoadNotice:
          detailUnavailable ? 'techCardDetailUnavailable'.tr() : null,
      clearTechCardLoadNotice: !detailUnavailable,
    );
  }

  void clearTechCardLoadNotice() {
    state = state.copyWith(clearTechCardLoadNotice: true);
  }

  void closeEditor() {
    state = state.copyWith(
      clearSelectedCell: true,
      clearEditor: true,
      clearTechCardLoadNotice: true,
    );
  }

  void updateEditorDraft(TechCardDraft draft) {
    state = state.copyWith(editorDraft: draft);
  }

  void rollbackEditor() {
    final original = state.editorOriginal;
    if (original == null) {
      return;
    }
    final restored = original.copyForSnapshot();
    restored.originalSnapshot = original;
    state = state.copyWith(editorDraft: restored);
  }

  /// Заполняет список ингредиентов редактора ингредиентами блюда
  /// (`GET /menu-items/{id}/ingredients`) — у них уже есть `ingredient_id`.
  /// Полуфабрикаты приходят без id: их добавляем, но клиентская валидация не
  /// даст сохранить, пока повар не выберет ингредиент вручную.
  Future<SaveResult> pullDishIngredients() async {
    final draft = state.editorDraft;
    if (draft == null || draft.menuItemId == null) {
      return SaveResult(error: 'dishIngredientsError'.tr());
    }
    try {
      final repo = ref.read(menuDashboardRepositoryProvider);
      final ingredients = await repo.loadDishIngredients(draft.menuItemId!);
      if (ingredients.isEmpty) {
        return SaveResult(notice: 'dishIngredientsEmpty'.tr());
      }
      draft.ingredients = ingredients;
      state = state.copyWith(editorDraft: draft);
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

  /// Сохраняет правки ячейки: техкарту (PATCH technical-cards) и, если порции
  /// плана изменились, отдельным запросом — planned_portions.
  ///
  /// Возвращает результат для UI: [SaveResult.error] — блокирующая ошибка
  /// (например, `PLAN_NOT_EDITABLE`, лист остаётся открытым); [SaveResult.notice]
  /// — информационное сообщение (план сброшен в draft); оба `null` — успех.
  Future<SaveResult> saveAndSign() async {
    final draft = state.editorDraft;
    final cellKey = state.selectedCellKey;
    if (draft == null || cellKey == null) {
      appLogger.w(
        'saveAndSign: nothing to save (draft=${draft != null}, '
        'cellKey=${cellKey != null})',
      );
      return const SaveResult();
    }

    final session = ref.read(authSessionProvider).valueOrNull;
    final signature = session == null
        ? 'MEZZOME'
        : '${session.name} | MEZZOME';

    final original = state.editorOriginal ?? draft.copyForSnapshot();
    final changes = draft.diffFrom(original);
    final repo = ref.read(menuDashboardRepositoryProvider);

    appLogger.i(
      'saveAndSign: cell=$cellKey, cardId=${draft.id}, '
      'menuItemId=${draft.menuItemId}, planItemId=${draft.planItemId}, '
      'readOnly=${draft.readOnly}, '
      'basePortions=${draft.portions}, plannedPortions=${draft.plannedPortions} '
      '(was ${original.plannedPortions}), '
      'changes=[${changes.map((c) => c.field).join(', ')}]',
    );

    // 1. Техкарта (название, выход, ингредиенты, base_portions) — своя ручка
    //    PATCH /chef/technical-cards/{id}. Количество порций ячейки сюда НЕ
    //    входит: base_portions — это базовые порции рецепта, не план на день.
    try {
      if (draft.id != null) {
        // Клиентская валидация зеркалит серверный INVALID_TECHNICAL_CARD —
        // показываем понятную причину сразу, не дёргая бэкенд впустую.
        final validationKey = draft.validationErrorKey();
        if (validationKey != null) {
          appLogger.w('saveAndSign: rejected by client validation: $validationKey');
          return SaveResult(error: validationKey.tr());
        }
        // Шеф подтверждает правку сам: сохраняем БЕЗ отправки на согласование
        // (submit_for_approval=false), затем сразу одобряем черновую версию
        // (POST .../approve). Бэкенд фиксирует изменение в истории техкарты.
        // Прочие роли (manager) — старый путь через очередь согласования.
        final isChef = session?.role == UserRole.chef;
        appLogger.i('saveAndSign: PATCH technical-card ${draft.id}…');
        final saved = await repo.saveTechnicalCard(
          id: draft.id!,
          draft: draft,
          submitForApproval: !isChef,
        );
        if (isChef) {
          final approveId = saved?.id ?? draft.id!;
          appLogger.i('saveAndSign: chef self-approve technical-card $approveId…');
          await repo.approveTechnicalCard(approveId);
        }
        appLogger.i('saveAndSign: technical-card ${draft.id} saved OK');
      } else {
        // Нет id техкарты (ячейка без привязанной карты) — серверный PATCH
        // не выполняется, правка фиксируется только локально в журнале.
        appLogger.w(
          'saveAndSign: draft has no card id — skipping server PATCH '
          '(local journal only)',
        );
      }
    } on DioException catch (error) {
      // Сервер отклонил запрос (валидация / карта уже на согласовании и т.п.) —
      // показываем настоящую причину и НЕ выдаём это за успех.
      if (error.response != null) {
        appLogger.w('Tech card save rejected: ${error.response?.data}');
        return SaveResult(
          error: apiErrorDetails(error) ?? 'techCardSaveError'.tr(),
        );
      }
      // Сети нет — оффлайн-фолбэк: фиксируем правку локально в журнале.
      appLogger.w('API save failed (network) — persisting locally');
    } catch (_) {
      appLogger.w('API save failed — persisting locally with journal entry');
    }

    // 2. Порции ячейки недельного плана — отдельная ручка
    //    PATCH /{role}/production-plan-items/{plan_item_id}. Дёргаем только если
    //    значение реально изменилось и у ячейки есть plan_item_id. Директор
    //    составляет план через manager-ручку, шеф — через chef.
    String? notice;
    final newPortions = draft.plannedPortions;
    final portionsChanged =
        newPortions != null && newPortions != original.plannedPortions;
    if (portionsChanged && draft.planItemId != null) {
      try {
        await repo.updatePlannedPortions(
          planItemId: draft.planItemId!,
          asManager: session?.role == UserRole.manager,
          plannedPortions: newPortions,
        );
        // Backend сбросил план в draft — нужен повторный check-stock + approve.
        notice = 'planResetToDraftNotice'.tr();
      } on PlanNotEditable {
        // Производство по ячейке уже началось — порции править нельзя.
        // Откатываем поле в редакторе и сообщаем пользователю.
        draft.plannedPortions = original.plannedPortions;
        state = state.copyWith(editorDraft: draft);
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
      summaryParts.add(
        'cost ${costChange.oldValue} → ${costChange.newValue} ₸',
      );
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
          .map(
            (c) => JournalFieldChange(
              field: c.field,
              oldValue: c.oldValue,
              newValue: c.newValue,
            ),
          )
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
    state = state.copyWith(
      journalEntries: [entry, ...state.journalEntries],
      modifiedCellKeys: modified,
      rows: updatedRows,
      editorOriginal: draft.copyForSnapshot(),
    );

    // Тихий рефреш с сервера: подтягиваем пересчитанные сервером значения
    // (стоимость, порции, имя) без полноэкранного спиннера — loadForDate с
    // refresh:true поднимает только isRefreshing (тонкая полоса прогресса).
    // Не дожидаемся: лист редактора закрывается сразу, таблица обновится фоном.
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
        if (cell.cellKey != cellKey) {
          return MapEntry(index, cell);
        }
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
      state = state.copyWith(modifiedCellKeys: modified);
      await loadForDate(_anchorDate!, refresh: true);
    }
  }
}

/// Итог [MenuDashboardNotifier.saveAndSign] для UI.
class SaveResult {
  const SaveResult({this.error, this.notice});

  /// Блокирующая ошибка — редактор не закрывать, показать пользователю.
  final String? error;

  /// Информационное уведомление (например, план сброшен в draft).
  final String? notice;
}

final menuDashboardNotifierProvider =
    NotifierProvider<MenuDashboardNotifier, MenuDashboardState>(
  MenuDashboardNotifier.new,
);

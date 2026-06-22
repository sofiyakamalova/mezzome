/// Editable tech card state for the side panel (client-side preview calc).
class TechCardDraft {
  TechCardDraft({
    this.id,
    this.name = '',
    this.serviceLabel = '',
    this.dayLabel = '',
    this.categoryLabel = '',
    this.outputGrams = 220,
    this.portions = 1,
    this.plannedPortions,
    this.planItemId,
    this.menuItemId,
    this.categoryId,
    this.lossPct = 5,
    this.notes = '',
    List<TechCardIngredientDraft>? ingredients,
    List<String>? photoUrls,
    this.serverCostPerPortion,
    this.originalSnapshot,
    this.scheduleless = false,
    this.readOnly = false,
    this.version,
    this.changeLevel,
    this.submittedAt,
    this.approvedAt,
    this.halalRequired = false,
  })  : ingredients = ingredients ?? [],
        photoUrls = photoUrls ?? [];

  final int? id;
  String name;
  String serviceLabel;
  String dayLabel;
  String categoryLabel;
  double outputGrams;

  /// Базовые порции рецепта техкарты (`base_portions`) — основа расчёта
  /// себестоимости. НЕ путать с [plannedPortions] (порции ячейки в плане).
  int portions;

  /// Порции ячейки недельного плана (`planned_portions`). Меняются отдельной
  /// ручкой `PATCH /chef/production-plan-items/{planItemId}`. `null`, если у
  /// ячейки нет привязки к строке плана (например, контекст «Мои запросы»).
  int? plannedPortions;

  /// `plan_item_id` ячейки — нужен для PATCH planned_portions.
  int? planItemId;

  /// `menu_item_id` блюда — уходит в PATCH техкарты (после approve обновит имя).
  int? menuItemId;

  /// `category_id` — нужен при создании техкарты с нуля.
  int? categoryId;
  double lossPct;
  String notes;
  List<TechCardIngredientDraft> ingredients;

  /// Фото блюда (`photo_urls`). Редактируемо: добавляем/удаляем URL'ы.
  List<String> photoUrls;

  /// Причина правки (manager → chef). Уходит в `approval_reason` при отправке.
  /// Транзиентна: не входит в snapshot/diff/копию.
  String editReason = '';

  /// Σ нетто на порцию (для панели сходимости массы).
  double get nettoSum =>
      ingredients.fold<double>(0, (s, i) => s + i.netto);

  /// Ожидаемый выход после ужарки: Σ нетто × (1 − lossPct%).
  double get expectedOutput => nettoSum * (1 - lossPct / 100);

  /// Расхождение массы в %: насколько заявленный выход отличается от
  /// ожидаемого (Σ нетто за вычетом ужарки). Так сырой вес и готовый выход
  /// сверяются корректно — ужарка не считается ошибкой. `null`, если нет данных.
  double? get massDivergencePct {
    if (outputGrams <= 0) return null;
    final expected = expectedOutput;
    if (expected <= 0) return null;
    return (outputGrams - expected) / expected * 100;
  }

  /// Сходится ли масса в пределах допуска ε (по умолчанию 5%).
  bool massConverges({double tolerancePct = 5}) {
    final pct = massDivergencePct;
    return pct == null || pct.abs() <= tolerancePct;
  }

  /// Карточка открыта вне недельной сетки (раздел «Мои запросы»): у неё нет
  /// привязки к приёму пищи/дню, поэтому в шапке показываем версию и даты
  /// изменения вместо `service · day`.
  final bool scheduleless;

  /// Только просмотр: версия уже на согласовании (редактировать/переотправлять
  /// нельзя). Редактор прячет ввод и кнопку отправки, показывает уведомление.
  final bool readOnly;

  /// Метаданные версии техкарты (для контекста «Мои запросы»).
  final int? version;
  final String? changeLevel;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  /// Себестоимость порции с бэкенда (`food_cost`), если в списке нет ингредиентов.
  final double? serverCostPerPortion;

  /// Требование халяль (`halal_required`) — редактируемо в форме.
  bool halalRequired;

  /// Deep copy captured when editor opens — used for rollback.
  TechCardDraft? originalSnapshot;

  double get portionCost {
    if (ingredients.isNotEmpty) {
      if (portions <= 0) {
        return 0;
      }
      final total = ingredients.fold<double>(
        0,
        (sum, row) => sum + row.lineCost,
      );
      return total / portions;
    }
    return serverCostPerPortion ?? 0;
  }

  /// Проверяет черновик против требований бэкенда к техкарте перед PATCH.
  /// Возвращает ключ локализации сообщения об ошибке либо `null`, если данные
  /// валидны. Зеркалит серверную валидацию (`INVALID_TECHNICAL_CARD`), чтобы
  /// пользователь увидел понятную причину до сетевого запроса.
  String? validationErrorKey() {
    if (ingredients.isEmpty) {
      return 'techCardValidationNoIngredients';
    }
    // Бэкенд требует ingredient_id (ссылку на справочник) у каждой строки —
    // без него PATCH вернёт 400 (с вводящим в заблуждение текстом про brutto).
    // Блокируем заранее: пользователь должен выбрать ингредиент из справочника.
    if (ingredients.any((row) => row.ingredientId == null)) {
      return 'techCardValidationIngredientId';
    }
    if (ingredients.any((row) => row.brutto <= 0 || row.netto <= 0)) {
      return 'techCardValidationBrutto';
    }
    // Нетто — вес после очистки, не может превышать брутто (зеркалит серверное
    // «netto must be > 0 and <= brutto»).
    if (ingredients.any((row) => row.netto > row.brutto)) {
      return 'techCardValidationNetto';
    }
    return null;
  }

  TechCardDraft copyForSnapshot() {
    return TechCardDraft(
      id: id,
      name: name,
      serviceLabel: serviceLabel,
      dayLabel: dayLabel,
      categoryLabel: categoryLabel,
      outputGrams: outputGrams,
      portions: portions,
      plannedPortions: plannedPortions,
      planItemId: planItemId,
      menuItemId: menuItemId,
      categoryId: categoryId,
      lossPct: lossPct,
      notes: notes,
      ingredients: ingredients.map((e) => e.copy()).toList(),
      photoUrls: List.of(photoUrls),
      serverCostPerPortion: serverCostPerPortion,
      scheduleless: scheduleless,
      readOnly: readOnly,
      version: version,
      changeLevel: changeLevel,
      submittedAt: submittedAt,
      approvedAt: approvedAt,
      halalRequired: halalRequired,
    );
  }

  List<({String field, String oldValue, String newValue})> diffFrom(
    TechCardDraft other,
  ) {
    final changes = <({String field, String oldValue, String newValue})>[];
    void add(String field, Object? oldV, Object? newV) {
      final o = '$oldV';
      final n = '$newV';
      if (o != n) {
        changes.add((field: field, oldValue: o, newValue: n));
      }
    }

    add('name', other.name, name);
    add('outputGrams', other.outputGrams, outputGrams);
    add('portions', other.portions, portions);
    add('plannedPortions', other.plannedPortions, plannedPortions);
    add('lossPct', other.lossPct, lossPct);
    add('notes', other.notes, notes);
    add('ingredients', other.ingredients.length, ingredients.length);
    add('portionCost', other.portionCost.toStringAsFixed(2),
        portionCost.toStringAsFixed(2));
    return changes;
  }
}

class TechCardIngredientDraft {
  TechCardIngredientDraft({
    this.id,
    this.ingredientId,
    this.name = '',
    this.brutto = 0,
    this.netto = 0,
    this.pricePerKg = 0,
    this.cleaningPct,
    this.cutType,
    this.nettoPerPortion,
    this.lossCoefficient,
    this.cookingLossCoefficient,
    this.lossReferenceId,
    this.lossSource,
    this.overrideReason,
  });

  final int? id;

  /// Ссылка на ингредиент в справочнике — обязательна для PATCH техкарты.
  /// Изменяемая: пикер проставляет id в ту же строку (идентичность объекта
  /// сохраняется, поэтому поля брутто/нетто не сбрасываются).
  int? ingredientId;
  String name;
  double brutto;
  double netto;

  /// Цена ₸/кг — справочная, бэкенд считает себестоимость сам (не отправляем).
  double pricePerKg;

  /// Поля потерь/обработки — переносим из карты и шлём обратно без изменений,
  /// чтобы не сломать «ручную ссылку на потери» (иначе approve → 400).
  double? cleaningPct;
  String? cutType;
  double? nettoPerPortion;
  double? lossCoefficient;
  double? cookingLossCoefficient;
  int? lossReferenceId;
  String? lossSource;
  String? overrideReason;

  double get lineCost => (netto / 1000) * pricePerKg;

  TechCardIngredientDraft copy() {
    return TechCardIngredientDraft(
      id: id,
      ingredientId: ingredientId,
      name: name,
      brutto: brutto,
      netto: netto,
      pricePerKg: pricePerKg,
      cleaningPct: cleaningPct,
      cutType: cutType,
      nettoPerPortion: nettoPerPortion,
      lossCoefficient: lossCoefficient,
      cookingLossCoefficient: cookingLossCoefficient,
      lossReferenceId: lossReferenceId,
      lossSource: lossSource,
      overrideReason: overrideReason,
    );
  }
}

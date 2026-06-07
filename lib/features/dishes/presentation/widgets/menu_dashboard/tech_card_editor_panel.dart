import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/ingredient_picker_sheet.dart';

class TechCardEditorPanel extends StatefulWidget {
  const TechCardEditorPanel({
    super.key,
    required this.draft,
    required this.signature,
    required this.onChanged,
    required this.onClose,
    required this.onRollback,
    required this.onSaveAndSign,
    required this.showFinancials,
    this.onShowHistory,
    this.onPullFromDish,
    this.selfApprove = false,
  });

  final TechCardDraft draft;
  final String signature;
  final ValueChanged<TechCardDraft> onChanged;
  final VoidCallback onClose;
  final VoidCallback onRollback;
  final Future<void> Function() onSaveAndSign;
  final bool showFinancials;

  /// Открыть историю версий техкарты. `null` — кнопка скрыта (нет id карты).
  final VoidCallback? onShowHistory;

  /// Подтянуть ингредиенты блюда (с готовыми `ingredient_id`). `null` —
  /// кнопка скрыта (нет привязки к блюду или нельзя редактировать).
  final Future<void> Function()? onPullFromDish;

  /// Шеф подтверждает правку сам (без отправки на согласование) — меняет
  /// подпись кнопки на «Сохранить и подтвердить».
  final bool selfApprove;

  @override
  State<TechCardEditorPanel> createState() => _TechCardEditorPanelState();
}

class _TechCardEditorPanelState extends State<TechCardEditorPanel> {
  bool _saving = false;

  /// Шапка для недельной сетки: «приём пищи · день» + категория.
  List<Widget> _scheduleHeader(BuildContext context, TechCardDraft draft) {
    return [
      Text(
        'techCardHeader'.tr(
          namedArgs: {
            'service': draft.serviceLabel,
            'day': draft.dayLabel,
          },
        ),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ThemePalette.onSurfaceMuted(context),
              letterSpacing: 0.6,
            ),
      ),
      Text(
        draft.categoryLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ThemePalette.accent(context),
            ),
      ),
    ];
  }

  /// Шапка для «Мои запросы»: версия, тип изменения и даты вместо service·day
  /// (техкарта здесь — версия рецепта, а не ячейка конкретного дня).
  List<Widget> _requestMetaHeader(BuildContext context, TechCardDraft draft) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final labelSmall = Theme.of(context).textTheme.labelSmall;
    return [
      Row(
        children: [
          if (draft.categoryLabel.isNotEmpty)
            Expanded(
              child: Text(
                draft.categoryLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ThemePalette.accent(context),
                    ),
              ),
            )
          else
            const Spacer(),
          if (draft.version != null || draft.changeLevel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                [
                  if (draft.version != null) 'v${draft.version}',
                  if (draft.changeLevel != null) draft.changeLevel!,
                ].join(' · '),
                style: labelSmall?.copyWith(
                  color: AppColors.warningAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      if (draft.submittedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'techCardSubmittedAt'.tr(
              namedArgs: {
                'date': DateFormatUtil.formatDateTimeShort(draft.submittedAt!),
              },
            ),
            style: labelSmall?.copyWith(color: muted),
          ),
        ),
      if (draft.approvedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'techCardApprovedAt'.tr(
              namedArgs: {
                'date': DateFormatUtil.formatDateTimeShort(draft.approvedAt!),
              },
            ),
            style: labelSmall?.copyWith(color: AppColors.profitGreen),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;

    return Material(
      color: ThemePalette.surfacePanel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: draft.scheduleless
                        ? _requestMetaHeader(context, draft)
                        : _scheduleHeader(context, draft),
                  ),
                ),
                if (widget.onShowHistory != null)
                  IconButton(
                    onPressed: widget.onShowHistory,
                    tooltip: 'techCardHistoryTooltip'.tr(),
                    icon: const Icon(Icons.history),
                  ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              children: [
                if (draft.readOnly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ReadOnlyBanner(),
                  ),
                _FormSection(
                  title: 'techCardBasicsSection'.tr(),
                  child: TextField(
                    readOnly: draft.readOnly,
                    decoration: InputDecoration(
                      labelText: 'dishNameLabel'.tr(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: draft.name)
                      ..selection =
                          TextSelection.collapsed(offset: draft.name.length),
                    onChanged: (v) {
                      draft.name = v;
                      widget.onChanged(draft);
                    },
                  ),
                ),
                _FormSection(
                  title: 'techCardYieldSection'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Порции ячейки недельного плана (planned_portions) —
                      // отдельная от техкарты сущность. Меняется ручкой
                      // production-plan-items; правка сбрасывает план в draft.
                      // Показываем, только если у ячейки есть строка плана.
                      if (!draft.scheduleless && draft.planItemId != null) ...[
                        _NumberField(
                          fieldKey: 'planned_${identityHashCode(draft)}',
                          label: 'plannedPortionsLabel'.tr(),
                          value: (draft.plannedPortions ?? 0).toDouble(),
                          isInt: true,
                          readOnly: draft.readOnly,
                          onChanged: (v) {
                            draft.plannedPortions = v.round().clamp(1, 9999);
                            widget.onChanged(draft);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xxs,
                            bottom: AppSpacing.sm,
                          ),
                          child: Text(
                            'plannedPortionsHint'.tr(),
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: ThemePalette.onSurfaceMuted(context),
                                    ),
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: _NumberField(
                              fieldKey: 'output_${identityHashCode(draft)}',
                              label: 'yieldGramsLabel'.tr(),
                              value: draft.outputGrams,
                              suffix: 'г',
                              readOnly: draft.readOnly,
                              onChanged: (v) {
                                draft.outputGrams = v;
                                widget.onChanged(draft);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _NumberField(
                              fieldKey: 'portions_${identityHashCode(draft)}',
                              label: 'basePortionsLabel'.tr(),
                              value: draft.portions.toDouble(),
                              isInt: true,
                              readOnly: draft.readOnly,
                              onChanged: (v) {
                                draft.portions = v.round().clamp(1, 9999);
                                widget.onChanged(draft);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _NumberField(
                              fieldKey: 'loss_${identityHashCode(draft)}',
                              label: 'lossPctLabel'.tr(),
                              value: draft.lossPct,
                              suffix: '%',
                              readOnly: draft.readOnly,
                              onChanged: (v) {
                                draft.lossPct = v;
                                widget.onChanged(draft);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _FormSection(
                  title: 'ingredientsTitle'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showFinancials)
                        _IngredientsTable(
                          draft: draft,
                          onChanged: widget.onChanged,
                          showFinancials: widget.showFinancials,
                          readOnly: draft.readOnly,
                        ),
                      if (!widget.showFinancials)
                        ...draft.ingredients.map(
                          (ing) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(ing.name),
                            subtitle: Text('${ing.netto.toStringAsFixed(0)} g'),
                          ),
                        ),
                      if (!draft.readOnly)
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final picked =
                                    await IngredientPickerSheet.show(context);
                                if (picked == null) return;
                                draft.ingredients.add(
                                  TechCardIngredientDraft(
                                    ingredientId: picked.id,
                                    name: picked.name,
                                    pricePerKg: picked.costPerUnit ?? 0,
                                  ),
                                );
                                widget.onChanged(draft);
                              },
                              icon: const Icon(Icons.add),
                              label: Text('addIngredient'.tr()),
                            ),
                            if (widget.onPullFromDish != null)
                              TextButton.icon(
                                onPressed: widget.onPullFromDish,
                                icon: const Icon(Icons.download_outlined),
                                label: Text('pullFromDishButton'.tr()),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                _FormSection(
                  title: 'techNotesLabel'.tr(),
                  child: TextField(
                    readOnly: draft.readOnly,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    minLines: 3,
                    maxLines: 5,
                    controller: TextEditingController(text: draft.notes)
                      ..selection =
                          TextSelection.collapsed(offset: draft.notes.length),
                    onChanged: (v) {
                      draft.notes = v;
                      widget.onChanged(draft);
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ThemePalette.border(context))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showFinancials)
                  Text(
                    'portionCostLabel'.tr(
                      namedArgs: {
                        'cost': draft.portionCost.toStringAsFixed(2),
                      },
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ThemePalette.accent(context),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                if (!draft.readOnly) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'signatureOnSave'
                        .tr(namedArgs: {'signature': widget.signature}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ThemePalette.onSurfaceMuted(context),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      TextButton(
                        onPressed: widget.onRollback,
                        child: Text('rollbackButton'.tr()),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                await widget.onSaveAndSign();
                                if (mounted) {
                                  setState(() => _saving = false);
                                }
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                widget.selfApprove
                                    ? Icons.check_rounded
                                    : Icons.send_rounded,
                                size: 18,
                              ),
                        label: Text(
                          widget.selfApprove
                              ? 'techCardSaveButton'.tr()
                              : 'submitForApprovalButton'.tr(),
                        ),
                      ),
                    ],
                  ),
                ],
                if (draft.readOnly)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onClose,
                      child: Text('closeButton'.tr()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Визуальная секция формы: заголовок-капитель + карточка с полями. Группирует
/// связанные поля, чтобы редактор техкарты читался блоками, а не сплошным
/// списком.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// Числовое поле с лейблом. Использует `TextFormField` + `initialValue` (без
/// пересоздания контроллера в build) — поэтому курсор не сбрасывается при
/// вводе. `Key` завязан на идентичность объекта-источника: меняется только
/// при откате (новый объект) → поле перечитывает значение.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.fieldKey,
    this.isInt = false,
    this.suffix,
    this.readOnly = false,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Object fieldKey;
  final bool isInt;
  final String? suffix;
  final bool readOnly;

  /// Текст для поля. Ноль показываем как пустую строку (через [hintText]),
  /// чтобы не приходилось стирать «0» перед вводом. Дробные граммовки
  /// сохраняем без округления: 12.32 → «12.32», 10.0 → «10».
  String _initialText() {
    if (value == 0) return '';
    if (isInt) return value.round().toString();
    final fixed = value.toStringAsFixed(2);
    return fixed
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(fieldKey),
      readOnly: readOnly,
      initialValue: _initialText(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        hintText: '0',
        suffixText: suffix,
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          isInt ? RegExp(r'\d') : RegExp(r'[\d.,]'),
        ),
      ],
      onChanged: (raw) {
        final parsed = double.tryParse(raw.replaceAll(',', '.')) ?? 0;
        onChanged(parsed);
      },
    );
  }
}

/// Ингредиенты как блоки: название на всю ширину, ниже «Брутто/Нетто» (г) и
/// сумма строки (₸, read-only — себестоимость считает бэкенд).
class _IngredientsTable extends StatelessWidget {
  const _IngredientsTable({
    required this.draft,
    required this.onChanged,
    required this.showFinancials,
    required this.readOnly,
  });

  final TechCardDraft draft;
  final ValueChanged<TechCardDraft> onChanged;
  final bool showFinancials;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in draft.ingredients.asMap().entries)
          _IngredientCard(
            index: entry.key,
            ing: entry.value,
            draft: draft,
            onChanged: onChanged,
            showFinancials: showFinancials,
            readOnly: readOnly,
          ),
      ],
    );
  }
}

/// Выбор ингредиента из справочника вместо свободного текста. Если у строки нет
/// `ingredient_id` (ручная/полуфабрикат), подсвечиваем как требующую выбора —
/// бэкенд без id вернёт ошибку.
class _IngredientSelector extends StatelessWidget {
  const _IngredientSelector({
    required this.ing,
    required this.readOnly,
    required this.onPick,
  });

  final TechCardIngredientDraft ing;
  final bool readOnly;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    final needsPick = ing.ingredientId == null;
    final hasName = ing.name.isNotEmpty;
    return InkWell(
      onTap: readOnly ? null : onPick,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'colName'.tr(),
          errorText:
              (!readOnly && needsPick) ? 'selectIngredientHint'.tr() : null,
          suffixIcon: readOnly
              ? null
              : const Icon(Icons.search, size: 20),
        ),
        child: Text(
          hasName ? ing.name : 'selectIngredientHint'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hasName
                    ? ThemePalette.onSurface(context)
                    : ThemePalette.onSurfaceMuted(context),
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.index,
    required this.ing,
    required this.draft,
    required this.onChanged,
    required this.showFinancials,
    required this.readOnly,
  });

  final int index;
  final TechCardIngredientDraft ing;
  final TechCardDraft draft;
  final ValueChanged<TechCardDraft> onChanged;
  final bool showFinancials;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    // Идентичность объекта ing стабильна при вводе и меняется при откате.
    final idTag = identityHashCode(ing);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: ThemePalette.border(context)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _IngredientSelector(
                  ing: ing,
                  readOnly: readOnly,
                  onPick: () async {
                    final picked = await IngredientPickerSheet.show(context);
                    if (picked == null) return;
                    ing.ingredientId = picked.id;
                    ing.name = picked.name;
                    if (picked.costPerUnit != null) {
                      ing.pricePerKg = picked.costPerUnit!;
                    }
                    onChanged(draft);
                  },
                ),
              ),
              if (!readOnly)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () {
                    draft.ingredients.removeAt(index);
                    onChanged(draft);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _NumberField(
                  fieldKey: 'brutto_$idTag',
                  label: 'colBrutto'.tr(),
                  value: ing.brutto,
                  suffix: 'г',
                  readOnly: readOnly,
                  onChanged: (v) {
                    ing.brutto = v;
                    onChanged(draft);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _NumberField(
                  fieldKey: 'netto_$idTag',
                  label: 'colNetto'.tr(),
                  value: ing.netto,
                  suffix: 'г',
                  readOnly: readOnly,
                  onChanged: (v) {
                    ing.netto = v;
                    onChanged(draft);
                  },
                ),
              ),
              if (showFinancials) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'colSum'.tr(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: ThemePalette.onSurfaceMuted(context),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${ing.lineCost.toStringAsFixed(0)} ₸',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Плашка «только просмотр»: версия уже на согласовании, её нельзя править.
class _ReadOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: AppColors.warningAmber),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'techCardReadOnlyNotice'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warningAmber,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

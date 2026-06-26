import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/domain/production_grid_status.dart';

/// Меню одного дня — единый «лист»: категории подзаголовками, блюда плотными
/// строками. На широком экране ширина ограничена и центрируется (адаптивно).
class DayMenuList extends StatelessWidget {
  const DayMenuList({
    super.key,
    required this.rows,
    required this.day,
    required this.selectedDate,
    required this.showFinancials,
    required this.onItemTap,
    this.onAddTap,
    this.onAddSlot,
    this.localSlots = const [],
  });

  final List<ProductionPlanGridRow> rows;
  final ProductionPlanGridDay? day;

  /// Дата просматриваемого дня — нужна, чтобы добавлять блюда даже когда план
  /// на этот день ещё пуст ([day] == null).
  final DateTime selectedDate;
  final bool showFinancials;
  final void Function(ProductionPlanGridCellItem item, DateTime? date)?
  onItemTap;

  /// Добавить блюдо в план дня. (date, slotKey, slotTitle) — как в сетке.
  final void Function(DateTime date, String? slotKey, String slotTitle)?
  onAddTap;

  /// «＋ Добавить слот» — новая локальная строка-категория (как в сетке).
  final VoidCallback? onAddSlot;

  /// Локальные слоты (ещё без блюд) — показываем пустыми карточками, чтобы в
  /// них можно было добавить первое блюдо прямо из режима «день».
  final List<({String key, String title})> localSlots;

  @override
  Widget build(BuildContext context) {
    final selectedDay = day;
    if (selectedDay == null) {
      return _empty(context);
    }
    final weekdayKey = (selectedDay.weekday ?? '').toLowerCase();

    final sections = <({ProductionPlanGridRow row, ProductionPlanGridCell cell})>[];
    for (final row in rows) {
      for (final cell in row.cells) {
        if ((cell.weekday ?? '').toLowerCase() == weekdayKey &&
            cell.items.isNotEmpty) {
          sections.add((row: row, cell: cell));
          break;
        }
      }
    }

    // Локальные слоты, ещё не наполненные блюдами (нет среди sections).
    final filledKeys =
        sections.map((s) => s.row.slotKey).whereType<String>().toSet();
    final emptySlots =
        localSlots.where((s) => !filledKeys.contains(s.key)).toList();

    if (sections.isEmpty && emptySlots.isEmpty) {
      return _empty(context);
    }

    final border = ThemePalette.border(context);

    Widget cardShell(List<Widget> children) => Container(
          decoration: BoxDecoration(
            color: ThemePalette.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );

    // Каждая категория — отдельная карточка (с отступом между ними), чтобы
    // позиции дня визуально отделялись друг от друга.
    Widget sectionCard(
      ({ProductionPlanGridRow row, ProductionPlanGridCell cell}) s,
    ) {
      final cellDate = DateTime.tryParse(s.cell.date ?? selectedDay.date ?? '');
      final children = <Widget>[
        _SectionHeader(title: s.row.slotTitle ?? s.row.slotKey ?? '—'),
      ];
      for (var ii = 0; ii < s.cell.items.length; ii++) {
        if (ii > 0) {
          children.add(
            Divider(height: 1, thickness: 1, color: border, indent: AppSpacing.md),
          );
        }
        children.add(
          _DayMenuTile(
            item: s.cell.items[ii],
            showFinancials: showFinancials,
            date: cellDate,
            onTap: onItemTap,
          ),
        );
      }
      if (onAddTap != null) {
        children.add(Divider(height: 1, thickness: 1, color: border));
        children.add(
          _AddTile(
            label: 'menuAddDish'.tr(),
            onTap: () => onAddTap!(
              cellDate ?? selectedDate,
              s.row.slotKey,
              s.row.slotTitle ?? '',
            ),
          ),
        );
      }
      return cardShell(children);
    }

    // Пустой локальный слот: заголовок + подсказка + «＋ Добавить блюдо».
    Widget emptySlotCard(({String key, String title}) slot) {
      return cardShell([
        _SectionHeader(title: slot.title),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 10, AppSpacing.md, 2),
          child: Text(
            'menuGridEmptySlot'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                ),
          ),
        ),
        if (onAddTap != null) ...[
          Divider(height: 1, thickness: 1, color: border),
          _AddTile(
            label: 'menuAddDish'.tr(),
            onTap: () => onAddTap!(selectedDate, slot.key, slot.title),
          ),
        ],
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DaySummaryHeader(day: selectedDay),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var si = 0; si < sections.length; si++) ...[
                if (si > 0) const SizedBox(height: AppSpacing.sm),
                sectionCard(sections[si]),
              ],
              for (final slot in emptySlots) ...[
                if (sections.isNotEmpty || emptySlots.first != slot)
                  const SizedBox(height: AppSpacing.sm),
                emptySlotCard(slot),
              ],
              const SizedBox(height: AppSpacing.sm),
              _DayActions(
                onAddDish: onAddTap == null
                    ? null
                    : () => onAddTap!(selectedDate, null, ''),
                onAddSlot: onAddSlot,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 40,
              color: ThemePalette.onSurfaceMuted(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'menuGridEmpty'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DayActions(
              onAddDish: onAddTap == null
                  ? null
                  : () => onAddTap!(selectedDate, null, ''),
              onAddSlot: onAddSlot,
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопки действий дня: «＋ Добавить блюдо» и «＋ Добавить слот».
class _DayActions extends StatelessWidget {
  const _DayActions({this.onAddDish, this.onAddSlot});

  final VoidCallback? onAddDish;
  final VoidCallback? onAddSlot;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    return Row(
      children: [
        if (onAddDish != null)
          Expanded(
            child: FilledButton.icon(
              onPressed: onAddDish,
              icon: const Icon(Icons.add, size: 18),
              label: Text('menuAddDish'.tr()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        if (onAddDish != null && onAddSlot != null)
          const SizedBox(width: AppSpacing.sm),
        if (onAddSlot != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAddSlot,
              icon: Icon(Icons.playlist_add, size: 18, color: accent),
              label: Text('menuAddSlot'.tr(),
                  style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(color: accent.withValues(alpha: 0.5)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Подзаголовок категории: акцентная плашка с цветной полоской слева.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    final tint = ThemePalette.isLight(context)
        ? AppColorsLight.surfaceSecondary
        : AppColors.surfaceElevated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 3,
      ),
      decoration: BoxDecoration(color: tint),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: ThemePalette.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плотная строка-кнопка «＋ добавить блюдо» в подвале карточки категории.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 18, color: accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Шапка дня: дата + сводка «человек · порций».
class _DaySummaryHeader extends StatelessWidget {
  const _DaySummaryHeader({required this.day});

  final ProductionPlanGridDay day;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(day.date ?? '');
    final title = date != null
        ? DateFormatUtil.formatDisplayDate(date, context.locale.toString())
        : (day.weekdayTitle ?? day.weekday ?? '—');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'gridDayMeta'.tr(
              namedArgs: {
                'people': '${day.peopleCount}',
                'portions': '${day.totalPortions}',
              },
            ),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ThemePalette.onSurfaceMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка блюда: статус · название · порции · ₸/порц · ›.
class _DayMenuTile extends StatelessWidget {
  const _DayMenuTile({
    required this.item,
    required this.showFinancials,
    required this.date,
    required this.onTap,
  });

  final ProductionPlanGridCellItem item;
  final bool showFinancials;
  final DateTime? date;
  final void Function(ProductionPlanGridCellItem item, DateTime? date)? onTap;

  @override
  Widget build(BuildContext context) {
    final status = gridCellStatusFor(item);
    final muted = ThemePalette.onSurfaceMuted(context);
    final total = item.theoreticalCost;
    final cost = (total != null && item.plannedPortions > 0)
        ? total / item.plannedPortions
        : total;

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(item, date),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Цветной чип статуса — заметный, вместо бледной точки.
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(Icons.restaurant_rounded,
                  size: 19, color: status.color),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.menuItemName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ThemePalette.onSurface(context),
                        ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (item.plannedPortions > 0)
                        _Pill(
                          text: 'portionsShort'.tr(
                              namedArgs: {'count': '${item.plannedPortions}'}),
                          color: status.color,
                        ),
                      if (showFinancials && cost != null) ...[
                        if (item.plannedPortions > 0)
                          const SizedBox(width: AppSpacing.xs),
                        Text(
                          'costPerPortionShort'
                              .tr(namedArgs: {'cost': cost.toStringAsFixed(0)}),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Цветная «таблетка» (порции, статус) — тонированный фон + цветной текст.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

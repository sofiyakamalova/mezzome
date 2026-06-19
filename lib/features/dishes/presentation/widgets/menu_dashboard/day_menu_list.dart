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
    required this.showFinancials,
    required this.onItemTap,
  });

  final List<ProductionPlanGridRow> rows;
  final ProductionPlanGridDay? day;
  final bool showFinancials;
  final void Function(ProductionPlanGridCellItem item, DateTime? date)?
  onItemTap;

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

    if (sections.isEmpty) {
      return _empty(context);
    }

    final border = ThemePalette.border(context);

    final cardChildren = <Widget>[];
    for (var si = 0; si < sections.length; si++) {
      final s = sections[si];
      final cellDate = DateTime.tryParse(s.cell.date ?? selectedDay.date ?? '');
      cardChildren.add(
        _SectionHeader(
          title: s.row.slotTitle ?? s.row.slotKey ?? '—',
          showTopBorder: si > 0,
        ),
      );
      for (var ii = 0; ii < s.cell.items.length; ii++) {
        if (ii > 0) {
          cardChildren.add(
            Divider(height: 1, thickness: 1, color: border, indent: AppSpacing.md),
          );
        }
        cardChildren.add(
          _DayMenuTile(
            item: s.cell.items[ii],
            showFinancials: showFinancials,
            date: cellDate,
            onTap: onItemTap,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DaySummaryHeader(day: selectedDay),
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: ThemePalette.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cardChildren,
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
          ],
        ),
      ),
    );
  }
}

/// Подзаголовок категории: плотная плашка с лёгким тоном.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.showTopBorder});

  final String title;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final border = ThemePalette.border(context);
    final tint = ThemePalette.isLight(context)
        ? AppColorsLight.surfaceSecondary
        : AppColors.surfaceElevated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: tint,
        border: Border(
          top: showTopBorder ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: ThemePalette.onSurfaceMuted(context),
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
    final total = item.theoreticalCost;
    final cost = (total != null && item.plannedPortions > 0)
        ? total / item.plannedPortions
        : total;
    final meta = <String>[
      if (item.plannedPortions > 0)
        'portionsShort'.tr(namedArgs: {'count': '${item.plannedPortions}'}),
      if (showFinancials && cost != null)
        'costPerPortionShort'.tr(namedArgs: {'cost': cost.toStringAsFixed(0)}),
    ];

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(item, date),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                item.menuItemName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  meta.join(' · '),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ThemePalette.onSurfaceMuted(context),
                  ),
                ),
              ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ThemePalette.onSurfaceMuted(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

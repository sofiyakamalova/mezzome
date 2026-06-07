import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_grid_model.dart';
import 'package:mezzome/features/dishes/domain/production_grid_status.dart';

/// Недельная сетка меню-борда «категория × день» (как в HTML-прототипе).
///
/// Строки — слоты/категории (`slot_title`), колонки — дни недели
/// (`weekday_title`). В ячейке — блюда со статус-точкой и числом порций.
class ProductionGridTable extends StatelessWidget {
  const ProductionGridTable({
    super.key,
    required this.rows,
    required this.days,
    this.serviceTitle,
    this.showFinancials = true,
    this.onItemTap,
  });

  final List<ProductionPlanGridRow> rows;
  final List<ProductionPlanGridDay> days;
  final String? serviceTitle;
  final bool showFinancials;

  /// Тап по блюду: блюдо + дата дня (для открытия техкарты).
  final void Function(ProductionPlanGridCellItem item, DateTime? date)?
  onItemTap;

  static const double _catColWidth = 132;
  static const double _dayColWidth = 156;

  @override
  Widget build(BuildContext context) {
    final border = ThemePalette.border(context);

    return Container(
      margin: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: serviceTitle == null
                ? 'menuGridTitle'.tr()
                : 'menuGridTitleService'.tr(
                    namedArgs: {'service': serviceTitle!},
                  ),
            badge: 'menuGridSize'.tr(
              namedArgs: {'rows': '${rows.length}', 'days': '${days.length}'},
            ),
          ),
          const _GridLegend(),
          Divider(height: 1, thickness: 1, color: border),
          if (rows.isEmpty || days.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'menuGridEmpty'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
              ),
            )
          else
            // Вертикальный скролл — у родительского CustomScrollView, здесь
            // только горизонтальный для широкой сетки. Table сам выравнивает
            // высоту ячеек строки (без IntrinsicHeight).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _catColWidth + days.length * _dayColWidth,
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  border: TableBorder(
                    horizontalInside: BorderSide(color: border),
                    verticalInside: BorderSide(color: border),
                  ),
                  columnWidths: {
                    0: const FixedColumnWidth(_catColWidth),
                    for (var i = 0; i < days.length; i++)
                      i + 1: const FixedColumnWidth(_dayColWidth),
                  },
                  children: [
                    _headerRow(context),
                    for (final row in rows) _bodyRow(context, row),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  TableRow _headerRow(BuildContext context) {
    final headerBg = ThemePalette.isLight(context)
        ? AppColorsLight.surfaceSecondary
        : Colors.white.withValues(alpha: 0.04);
    final mutedStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ThemePalette.onSurfaceMuted(context),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return TableRow(
      decoration: BoxDecoration(color: headerBg),
      children: [
        _cell(child: Text('gridRowHeader'.tr(), style: mutedStyle)),
        for (final day in days)
          _cell(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (day.weekdayTitle ?? day.weekday ?? '—').toUpperCase(),
                  style: mutedStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'gridDayMeta'.tr(
                    namedArgs: {
                      'people': '${day.peopleCount}',
                      'portions': '${day.totalPortions}',
                    },
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ThemePalette.onSurfaceMuted(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  TableRow _bodyRow(BuildContext context, ProductionPlanGridRow row) {
    final catBg = ThemePalette.isLight(context)
        ? AppColorsLight.surfaceSecondary
        : Colors.white.withValues(alpha: 0.02);

    // Индекс ячеек строки по дню недели для выравнивания с колонками.
    final cellByWeekday = <String, ProductionPlanGridCell>{};
    for (final cell in row.cells) {
      final key = (cell.weekday ?? cell.date ?? '').toLowerCase();
      cellByWeekday[key] = cell;
    }

    return TableRow(
      children: [
        // Категорийная ячейка тянется на всю высоту строки (fill), чтобы фон
        // заполнял её целиком — высоту строки задают день-ячейки.
        _cell(
          background: catBg,
          fill: true,
          child: Text(
            row.slotTitle ?? row.slotKey ?? '—',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final day in days)
          Builder(
            builder: (_) {
              final cell = cellByWeekday[(day.weekday ?? '').toLowerCase()];
              return _cell(
                child: _DayCell(
                  cell: cell,
                  date: DateTime.tryParse(cell?.date ?? ''),
                  showFinancials: showFinancials,
                  onItemTap: onItemTap,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _cell({
    required Widget child,
    Color? background,
    Alignment alignment = Alignment.centerLeft,
    bool fill = false,
  }) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 54),
      color: background,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xs,
      ),
      child: child,
    );
    if (!fill) {
      return content;
    }
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: content,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.cell,
    required this.date,
    required this.showFinancials,
    this.onItemTap,
  });

  final ProductionPlanGridCell? cell;
  final DateTime? date;
  final bool showFinancials;
  final void Function(ProductionPlanGridCellItem item, DateTime? date)?
  onItemTap;

  @override
  Widget build(BuildContext context) {
    final items = cell?.items ?? const [];
    if (items.isEmpty) {
      return Text(
        '—',
        style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          _DishLine(
            item: item,
            showFinancials: showFinancials,
            onTap: onItemTap == null ? null : () => onItemTap!(item, date),
          ),
      ],
    );
  }
}

class _DishLine extends StatelessWidget {
  const _DishLine({
    required this.item,
    required this.showFinancials,
    this.onTap,
  });

  final ProductionPlanGridCellItem item;
  final bool showFinancials;
  final VoidCallback? onTap;

  /// Себестоимость порции = theoretical_cost / planned_portions.
  double? get _costPerPortion {
    final total = item.theoreticalCost;
    if (total == null || item.plannedPortions <= 0) {
      return total;
    }
    return total / item.plannedPortions;
  }

  @override
  Widget build(BuildContext context) {
    final status = gridCellStatusFor(item);
    final cost = _costPerPortion;
    final metaParts = <String>[
      if (item.plannedPortions > 0)
        'portionsShort'.tr(namedArgs: {'count': '${item.plannedPortions}'}),
      if (showFinancials && cost != null)
        'costPerPortionShort'.tr(namedArgs: {'cost': cost.toStringAsFixed(0)}),
    ];

    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 6),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItemName ?? '—',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (metaParts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      metaParts.join(' · '),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ThemePalette.onSurfaceMuted(context),
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // if (item.technicalCardId != null)
          //   Tooltip(
          //     message: 'techCardHistoryTooltip'.tr(),
          //     child: InkWell(
          //       onTap: () => TechCardHistorySheet.show(
          //         context,
          //         cardId: item.technicalCardId!,
          //         cardName: item.technicalCardName ?? item.menuItemName ?? '',
          //       ),
          //       customBorder: const CircleBorder(),
          //       child: Padding(
          //         padding: const EdgeInsets.only(left: 2, top: 1),
          //         child: Icon(
          //           Icons.history,
          //           size: 15,
          //           color: ThemePalette.onSurfaceMuted(context),
          //         ),
          //       ),
          //     ),
          //   ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: ThemePalette.onSurfaceMuted(context),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return line;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: line,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.badge});

  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs + 4,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: ThemePalette.isLight(context)
                  ? AppColorsLight.surfaceSecondary
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              badge,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridLegend extends StatelessWidget {
  const _GridLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs + 2,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final status in GridCellStatus.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  status.labelKey.tr(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ThemePalette.onSurfaceMuted(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

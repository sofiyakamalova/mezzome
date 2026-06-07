import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/l10n/weekday_labels.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';

class MenuWeekGrid extends StatelessWidget {
  const MenuWeekGrid({
    super.key,
    required this.rows,
    required this.weekDays,
    required this.selectedCellKey,
    required this.showFinancials,
    required this.onCellTap,
    required this.onCellRevert,
  });

  final List<MenuGridRow> rows;
  final List<DateTime> weekDays;
  final String? selectedCellKey;
  final bool showFinancials;
  final ValueChanged<MenuGridCell> onCellTap;
  final ValueChanged<MenuGridCell> onCellRevert;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'menuGridEmpty'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final weekdayLabels = localizedWeekdayLabels();
    const cellWidth = 140.0;
    const rowLabelWidth = 120.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              SizedBox(
                width: rowLabelWidth,
                child: Text(
                  'gridRowHeader'.tr(),
                  style: _headerStyle(context),
                ),
              ),
              for (var i = 0; i < weekDays.length; i++)
                SizedBox(
                  width: cellWidth,
                  child: Column(
                    children: [
                      Text(
                        weekdayLabels[weekDays[i].weekday - DateTime.monday]
                            .toUpperCase(),
                        style: _headerStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${weekDays[i].day}',
                        style: _headerStyle(context)?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: rowLabelWidth,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  for (var dayIndex = 0;
                      dayIndex < weekDays.length;
                      dayIndex++)
                    _GridCell(
                      width: cellWidth,
                      cell: row.cellsByDayIndex[dayIndex]!,
                      isSelected:
                          row.cellsByDayIndex[dayIndex]!.cellKey ==
                              selectedCellKey,
                      showFinancials: showFinancials,
                      onTap: () => onCellTap(row.cellsByDayIndex[dayIndex]!),
                      onRevert: row.cellsByDayIndex[dayIndex]!.isModified
                          ? () =>
                              onCellRevert(row.cellsByDayIndex[dayIndex]!)
                          : null,
                    ),
                ],
              ),
            );
          }),
          ],
        ),
      ),
    );
  }

  TextStyle? _headerStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ThemePalette.onSurfaceMuted(context),
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.width,
    required this.cell,
    required this.isSelected,
    required this.showFinancials,
    required this.onTap,
    this.onRevert,
  });

  final double width;
  final MenuGridCell cell;
  final bool isSelected;
  final bool showFinancials;
  final VoidCallback onTap;
  final VoidCallback? onRevert;

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormatUtil.isToday(cell.date);
    final hasPlan = !cell.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Material(
        color: ThemePalette.controlFill(context, selected: isSelected),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: ThemePalette.controlBorder(
            context,
            selected: isSelected,
            highlight: isToday && !isSelected,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onRevert,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            width: width,
            height: 72,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!hasPlan)
                        Expanded(
                          child: Center(
                            child: Text(
                              'notAvailable'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: ThemePalette.onSurfaceMuted(context),
                                  ),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          'portionsCount'.tr(
                            namedArgs: {
                              'count': '${cell.plannedPortions}',
                            },
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (showFinancials && cell.costPerPortion != null)
                          Text(
                            'costPerPortionShort'.tr(
                              namedArgs: {
                                'cost':
                                    cell.costPerPortion!.toStringAsFixed(0),
                              },
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color:
                                      ThemePalette.onSurfaceMuted(context),
                                ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (cell.isModified)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ThemePalette.accent(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

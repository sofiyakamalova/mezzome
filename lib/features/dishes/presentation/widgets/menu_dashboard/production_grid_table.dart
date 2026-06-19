import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/domain/production_grid_status.dart';

/// Недельная сетка меню-борда «категория × день» (как в HTML-прототипе).
///
/// Строки — слоты/категории (`slot_title`), колонки — дни недели
/// (`weekday_title`). В ячейке — блюда со статус-точкой и числом порций.
///
/// Ячейки нарисованы отдельными «выпуклыми» карточками (тень + скругление +
/// зазоры). На широких экранах (десктоп/браузер) день-колонки растягиваются,
/// заполняя всю ширину; на узких — включается горизонтальный скролл с
/// минимальными ширинами колонок. По тапу ячейка получает акцентный бордер.
class ProductionGridTable extends StatefulWidget {
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

  @override
  State<ProductionGridTable> createState() => _ProductionGridTableState();
}

class _ProductionGridTableState extends State<ProductionGridTable> {
  /// Минимальные ширины колонок (до растягивания на широких экранах).
  static const double _catColWidth = 132;
  static const double _dayColWidth = 156;

  /// Зазор между ячейками и вокруг сетки — за счёт него ячейки «отрываются»
  /// друг от друга и читаются как отдельные выпуклые карточки.
  static const double _gap = 6;

  /// Ключ выбранной ячейки `slot|weekday`. Сохраняется после тапа, давая
  /// акцентный бордер.
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final border = ThemePalette.border(context);
    final rows = widget.rows;
    final days = widget.days;

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
            title: widget.serviceTitle == null
                ? 'menuGridTitle'.tr()
                : 'menuGridTitleService'.tr(
                    namedArgs: {'service': widget.serviceTitle!},
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
            _buildGrid(context, rows, days),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<ProductionPlanGridRow> rows,
    List<ProductionPlanGridDay> days,
  ) {
    return Container(
      color: _panelBg(context),
      padding: const EdgeInsets.all(_gap),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = days.length;
          // Внутренние зазоры: по одному перед каждой день-колонкой.
          final naturalWidth =
              _catColWidth + cols * _dayColWidth + cols * _gap;
          final available = constraints.maxWidth;
          final fits = available >= naturalWidth;

          final catW = _catColWidth;
          var dayW = _dayColWidth;
          if (fits && cols > 0) {
            // Лишнюю ширину поровну отдаём день-колонкам → сетка заполняет экран.
            dayW = _dayColWidth + (available - naturalWidth) / cols;
          }

          final grid = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _gridRow(_headerCells(context, days, catW, dayW)),
              for (final row in rows) ...[
                const SizedBox(height: _gap),
                _gridRow(_bodyCells(context, row, days, catW, dayW)),
              ],
            ],
          );

          if (fits) {
            return grid;
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: naturalWidth, child: grid),
          );
        },
      ),
    );
  }

  /// Строка сетки: ячейки одной высоты (IntrinsicHeight) с зазорами.
  Widget _gridRow(List<Widget> cells) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) children.add(const SizedBox(width: _gap));
      children.add(cells[i]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  List<Widget> _headerCells(
    BuildContext context,
    List<ProductionPlanGridDay> days,
    double catW,
    double dayW,
  ) {
    final mutedStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ThemePalette.onSurfaceMuted(context),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    final headerBg = _secondaryBg(context);

    return [
      _card(
        width: catW,
        background: headerBg,
        child: Text('gridRowHeader'.tr(), style: mutedStyle),
      ),
      for (final day in days)
        _card(
          width: dayW,
          background: headerBg,
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
    ];
  }

  List<Widget> _bodyCells(
    BuildContext context,
    ProductionPlanGridRow row,
    List<ProductionPlanGridDay> days,
    double catW,
    double dayW,
  ) {
    // Индекс ячеек строки по дню недели для выравнивания с колонками.
    final cellByWeekday = <String, ProductionPlanGridCell>{};
    for (final cell in row.cells) {
      final key = (cell.weekday ?? cell.date ?? '').toLowerCase();
      cellByWeekday[key] = cell;
    }

    return [
      _card(
        width: catW,
        background: _secondaryBg(context),
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
            final key =
                '${row.slotKey ?? row.slotTitle}|'
                '${day.weekday ?? day.weekdayTitle}';
            final selected = key == _selectedKey;
            void select() => setState(() => _selectedKey = key);

            return _card(
              width: dayW,
              background: _cellBg(context),
              raised: true,
              selected: selected,
              alignment: Alignment.topLeft,
              onTap: select,
              child: _DayCell(
                cell: cell,
                date: DateTime.tryParse(cell?.date ?? ''),
                showFinancials: widget.showFinancials,
                onItemTap: widget.onItemTap,
                onSelect: select,
              ),
            );
          },
        ),
    ];
  }

  /// «Выпуклая» ячейка: Material с тенью (elevation), скруглением и бордером.
  /// Выбранная — с акцентным бордером и более глубокой тенью.
  Widget _card({
    required double width,
    required Widget child,
    required Color background,
    bool raised = false,
    bool selected = false,
    Alignment alignment = Alignment.centerLeft,
    VoidCallback? onTap,
  }) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    final borderColor = selected
        ? ThemePalette.accent(context)
        : ThemePalette.border(context);

    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: child,
    );

    return SizedBox(
      width: width,
      child: Material(
        color: background,
        elevation: selected ? 3 : (raised ? 1.5 : 0),
        shadowColor: ThemePalette.isLight(context)
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }

  Color _panelBg(BuildContext context) => ThemePalette.isLight(context)
      ? AppColorsLight.surface
      : AppColors.background;

  Color _cellBg(BuildContext context) => ThemePalette.isLight(context)
      ? AppColorsLight.surface
      : AppColors.surfaceElevated;

  Color _secondaryBg(BuildContext context) => ThemePalette.isLight(context)
      ? AppColorsLight.surfaceSecondary
      : AppColors.surface;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.cell,
    required this.date,
    required this.showFinancials,
    this.onItemTap,
    this.onSelect,
  });

  final ProductionPlanGridCell? cell;
  final DateTime? date;
  final bool showFinancials;
  final void Function(ProductionPlanGridCellItem item, DateTime? date)?
  onItemTap;
  final VoidCallback? onSelect;

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
            onTap: onItemTap == null
                ? null
                : () {
                    onSelect?.call();
                    onItemTap!(item, date);
                  },
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
  const _PanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs + 4,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

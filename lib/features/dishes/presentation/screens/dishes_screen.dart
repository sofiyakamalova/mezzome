import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/l10n/weekday_labels.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/core/widgets/app_flushbar.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_grid_model.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/presentation/providers/menu_dashboard_notifier.dart';
import 'package:mezzome/features/dishes/presentation/providers/production_grid_notifier.dart';
import 'package:mezzome/features/dishes/presentation/screens/tech_card_page.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/day_menu_list.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/menu_dashboard_app_bar_title.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/production_grid_table.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/service_tabs.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/week_range_selector.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/tech_card_editor_sheet.dart';

/// Режим показа меню-борда.
enum _MenuViewMode {
  /// Один выбранный день — листается по календарю без ограничения неделей.
  day,

  /// Вся неделя (7 дней, все блюда) — как раньше.
  week,
}

/// §6.1 — меню-борд (`/chef/production-plans/grid`). Два режима:
/// «день» — лента дней недели + меню одного дня сгруппировано по категориям;
/// «неделя» — матрица «категория × день» за 7 дней. Данные грузятся на неделю.
/// Тумблер режима — в AppBar. Тап по блюду → техкарта снизу.
class DishesScreen extends ConsumerStatefulWidget {
  const DishesScreen({super.key});

  @override
  ConsumerState<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends ConsumerState<DishesScreen> {
  /// Текущий режим показа. По умолчанию — один день.
  _MenuViewMode _viewMode = _MenuViewMode.day;

  /// Выбранная дата в режиме «день». null → сегодня.
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productionGridNotifierProvider.notifier).load();
    });
  }

  /// Прокручиваемая лента дат: неделя до текущей + ~6 недель вперёд.
  List<DateTime> _stripDates() {
    final start = DateFormatUtil.startOfWeek(
      DateFormatUtil.today,
    ).subtract(const Duration(days: 7));
    return List.generate(49, (i) => start.add(Duration(days: i)));
  }

  /// День сетки, соответствующий [date] (null, если загружена другая неделя).
  ProductionPlanGridDay? _dayForDate(
    List<ProductionPlanGridDay> days,
    DateTime date,
  ) {
    for (final day in days) {
      final d = DateTime.tryParse(day.date ?? '');
      if (d != null && DateFormatUtil.isSameDay(d, date)) {
        return day;
      }
    }
    return null;
  }

  /// Тап по блюду в сетке → полноэкранная страница техкарты. Редактирование
  /// по-прежнему через bottom-sheet (кнопка «Редактировать» на странице).
  Future<void> _openTechCardPage({
    required ProductionPlanGridCellItem item,
    required DateTime? date,
    required String signature,
    required bool showFinancials,
  }) {
    return TechCardPage.open(
      context,
      item: item,
      date: date,
      signature: signature,
      showFinancials: showFinancials,
      onEdit: () => _openGridDishSheet(
        item: item,
        date: date,
        signature: signature,
        showFinancials: showFinancials,
      ),
    );
  }

  /// Тап по блюду в сетке → MenuGridCell → bottom-sheet техкарты (§6.2).
  Future<void> _openGridDishSheet({
    required ProductionPlanGridCellItem item,
    required DateTime? date,
    required String signature,
    required bool showFinancials,
  }) async {
    final portions = item.plannedPortions;
    final total = item.theoreticalCost;
    final costPerPortion =
        (total != null && portions > 0) ? total / portions : total;
    final cell = MenuGridCell(
      rowKey: 'grid_${item.menuItemId ?? item.planItemId ?? item.menuItemName}',
      rowLabel: item.categoryName ?? '',
      date: date ?? DateFormatUtil.today,
      menuItemId: item.menuItemId,
      dishName: item.menuItemName ?? '',
      plannedPortions: portions > 0 ? portions : null,
      costPerPortion: costPerPortion,
      // Пробрасываем идентификаторы из grid — иначе редактор не знает,
      // какую техкарту патчить (cardId=null) и какую строку плана менять.
      technicalCardId: item.technicalCardId,
      technicalCardVersion: item.technicalCardVersion,
      planItemId: item.planItemId,
      planStatus: item.status,
    );
    await _openDishBottomSheet(
      cell: cell,
      signature: signature,
      showFinancials: showFinancials,
    );
  }

  Future<void> _openDishBottomSheet({
    required MenuGridCell cell,
    required String signature,
    required bool showFinancials,
  }) async {
    final notifier = ref.read(menuDashboardNotifierProvider.notifier);
    await notifier.selectCell(cell);
    if (!mounted) {
      return;
    }

    final dashboard = ref.read(menuDashboardNotifierProvider);
    if (dashboard.editorDraft == null) {
      return;
    }

    final notice = dashboard.techCardLoadNotice;
    if (notice != null && context.mounted) {
      AppFlushbar.showInfo(context, notice);
      notifier.clearTechCardLoadNotice();
    }

    await TechCardEditorSheet.show(
      context,
      signature: signature,
      showFinancials: showFinancials,
    );

    notifier.closeEditor();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final role = session?.role;
    final showFinancials = role != null && canSeeFinancials(role);
    final signature = session == null ? 'MEZZOME' : '${session.name} | MEZZOME';

    final grid = ref.watch(productionGridNotifierProvider);
    final gridNotifier = ref.read(productionGridNotifierProvider.notifier);

    // Первичная загрузка, если сетка ещё не загружена.
    if (grid.grid == null && !grid.isLoading && grid.errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => gridNotifier.load());
    }

    final isDayView = _viewMode == _MenuViewMode.day;
    final selectedDate = _selectedDate ?? DateFormatUtil.today;
    final selectedDay = isDayView ? _dayForDate(grid.days, selectedDate) : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: AppSpacing.sm,
        title: MenuDashboardAppBarTitle(signature: signature),
        actions: [
          _ViewModeToggle(
            mode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        color: ThemePalette.accent(context),
        onRefresh: gridNotifier.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: isDayView
                    ? _DayStrip(
                        dates: _stripDates(),
                        selectedDate: selectedDate,
                        onSelect: (date) {
                          setState(() => _selectedDate = date);
                          // Подгружаем неделю выбранной даты (no-op, если та же).
                          gridNotifier.load(anchorDate: date);
                        },
                      )
                    : WeekRangeSelector(
                        weekStart: grid.weekStart,
                        onPrev: () => gridNotifier.shiftWeek(-1),
                        onNext: () => gridNotifier.shiftWeek(1),
                        onToday: gridNotifier.goToCurrentWeek,
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: ServiceTabs(
                selected: grid.service,
                onSelected: gridNotifier.selectService,
              ),
            ),
            if (grid.isLoading || grid.isRefreshing)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (grid.errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _GridNotice(message: grid.errorMessage!),
                ),
              ),
            if (isDayView)
              SliverToBoxAdapter(
                child: DayMenuList(
                  rows: grid.rows,
                  day: selectedDay,
                  showFinancials: showFinancials,
                  onItemTap: (item, date) => _openTechCardPage(
                    item: item,
                    date: date,
                    signature: signature,
                    showFinancials: showFinancials,
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ProductionGridTable(
                  rows: grid.rows,
                  days: grid.days,
                  serviceTitle: grid.grid?.serviceTypeTitle,
                  showFinancials: showFinancials,
                  onItemTap: (item, date) => _openTechCardPage(
                    item: item,
                    date: date,
                    signature: signature,
                    showFinancials: showFinancials,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Мягкая плашка-предупреждение (например, «Сетка меню недоступна»):
/// янтарный текст на светло-янтарном фоне, плоская, со скруглением.
class _GridNotice extends StatelessWidget {
  const _GridNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isLight = ThemePalette.isLight(context);
    final bg = isLight
        ? const Color(0xFFFAEEDA)
        : AppColors.warningAmber.withValues(alpha: 0.12);
    final fg = isLight ? const Color(0xFF854F0B) : AppColors.warningAmber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
      ),
    );
  }
}

/// Компактный тумблер «День / Неделя» для AppBar — две иконки-сегмента.
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});

  final _MenuViewMode mode;
  final ValueChanged<_MenuViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: ThemePalette.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(
            context,
            icon: Icons.view_agenda_outlined,
            tooltip: 'menuViewDay'.tr(),
            selected: mode == _MenuViewMode.day,
            onTap: () => onChanged(_MenuViewMode.day),
          ),
          _seg(
            context,
            icon: Icons.calendar_view_week_outlined,
            tooltip: 'menuViewWeek'.tr(),
            selected: mode == _MenuViewMode.week,
            onTap: () => onChanged(_MenuViewMode.week),
          ),
        ],
      ),
    );
  }

  Widget _seg(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = ThemePalette.accent(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 34,
          alignment: Alignment.center,
          color: selected ? accent.withValues(alpha: 0.14) : null,
          child: Icon(
            icon,
            size: 18,
            color: selected ? accent : ThemePalette.onSurfaceMuted(context),
          ),
        ),
      ),
    );
  }
}

/// Прокручиваемая лента дат (несколько недель) — горизонтальный скролл.
/// Тап по дате → меню этого дня. Автоскролл к выбранной дате.
class _DayStrip extends StatefulWidget {
  const _DayStrip({
    required this.dates,
    required this.selectedDate,
    required this.onSelect,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  static const double _chipWidth = 50;
  static const double _sep = AppSpacing.xs;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _DayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateFormatUtil.isSameDay(
      oldWidget.selectedDate,
      widget.selectedDate,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_controller.hasClients) {
      return;
    }
    final index = widget.dates.indexWhere(
      (d) => DateFormatUtil.isSameDay(d, widget.selectedDate),
    );
    if (index < 0) {
      return;
    }
    final target = index * (_chipWidth + _sep) - 120;
    _controller.animateTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        itemCount: widget.dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: _sep),
        itemBuilder: (context, index) {
          final date = widget.dates[index];
          final isSelected = DateFormatUtil.isSameDay(
            date,
            widget.selectedDate,
          );
          return _DayChip(
            label: localizedWeekdayLabels()[date.weekday - DateTime.monday],
            day: date.day,
            isSelected: isSelected,
            isToday: DateFormatUtil.isToday(date),
            onTap: () => widget.onSelect(date),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final int? day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    return Material(
      color: ThemePalette.controlFill(context, selected: isSelected),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: ThemePalette.controlBorder(
          context,
          selected: isSelected,
          highlight: isToday && !isSelected,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ThemePalette.chipMutedLabelColor(
                    context,
                    selected: isSelected,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              if (day != null)
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ThemePalette.chipLabelColor(
                      context,
                      selected: isSelected,
                      accent: isToday,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

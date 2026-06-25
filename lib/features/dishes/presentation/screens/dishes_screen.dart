import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/l10n/weekday_labels.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/presentation/blocs/production_grid_bloc.dart';
import 'package:mezzome/features/dishes/presentation/screens/create_plan_screen.dart';
import 'package:mezzome/features/dishes/presentation/screens/tech_card_edit_page.dart';
import 'package:mezzome/features/dishes/presentation/screens/production_card_screen.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/day_menu_list.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/menu_dashboard_app_bar_title.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/production_grid_table.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/service_tabs.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/week_range_selector.dart';

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
class DishesScreen extends StatefulWidget {
  const DishesScreen({super.key});

  @override
  State<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends State<DishesScreen> {
  /// Текущий режим показа. По умолчанию — один день.
  _MenuViewMode _viewMode = _MenuViewMode.day;

  /// Выбранная дата в режиме «день». null → сегодня.
  DateTime? _selectedDate;

  /// Сетка меню-борда на BLoC. Роль берём из сессии (экран открыт авторизованно).
  late final ProductionGridBloc _gridBloc;

  UserRole? _role;

  @override
  void initState() {
    super.initState();
    _role = sl<AuthSessionCubit>().state.role;
    _gridBloc = sl<ProductionGridBloc>(param1: _role)
      ..add(const GridLoadRequested());
  }

  /// Тап по пустой ячейке → шторка с подсказкой; планировщику (manager) —
  /// кнопка «Создать план» (chef планы не создаёт).
  void _onAddEmpty(DateTime? date, String slotTitle) {
    final canPlan = _role == UserRole.manager;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slotTitle.isEmpty ? 'menuGridSlot'.tr() : slotTitle,
                style: Theme.of(sheetCtx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (date != null) ...[
                const SizedBox(height: 2),
                Text(DateFormatUtil.apiDate(date),
                    style: TextStyle(
                        color: ThemePalette.onSurfaceMuted(sheetCtx))),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('menuGridEmptySlot'.tr(),
                  style: TextStyle(
                      color: ThemePalette.onSurfaceMuted(sheetCtx))),
              const SizedBox(height: AppSpacing.md),
              if (canPlan)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CreatePlanScreen()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text('createPlanTitle'.tr()),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gridBloc.close();
    super.dispose();
  }

  /// Прокручиваемая лента дат: ~6 недель до текущей и ~6 недель вперёд —
  /// чтобы листать и прошлый месяц, и будущий. Выбор даты из другой недели
  /// догружает сетку на эту неделю (см. onSelect → GridLoadRequested).
  List<DateTime> _stripDates() {
    final start = DateFormatUtil.startOfWeek(
      DateFormatUtil.today,
    ).subtract(const Duration(days: 42));
    return List.generate(91, (i) => start.add(Duration(days: i)));
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
  /// Тап по блюду в меню → «Производственная карта» (техкарта × план-порции +
  /// факт), а не сырой норматив. Норматив-данные грузятся из техкарты блюда.
  Future<void> _openTechCardPage({
    required ProductionPlanGridCellItem item,
    required DateTime? date,
    required String signature,
    required bool showFinancials,
  }) {
    return ProductionCardScreen.open(
      context,
      item: item,
      date: date,
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
    // Полноэкранный редактор (грузит данные внутри, без «зависания»).
    await TechCardEditPage.open(
      context,
      cell: cell,
      signature: signature,
      showFinancials: showFinancials,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<AuthSessionCubit>().state.user;
    final role = session?.role;
    final showFinancials = role != null && canSeeFinancials(role);
    final signature = session == null ? 'MEZZOME' : '${session.name} | MEZZOME';

    final isDayView = _viewMode == _MenuViewMode.day;
    final selectedDate = _selectedDate ?? DateFormatUtil.today;

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
      body: BlocBuilder<ProductionGridBloc, ProductionGridState>(
        bloc: _gridBloc,
        builder: (context, grid) {
          final selectedDay =
              isDayView ? _dayForDate(grid.days, selectedDate) : null;
          return RefreshIndicator(
            color: ThemePalette.accent(context),
            onRefresh: () async =>
                _gridBloc.add(const GridRefreshRequested()),
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
                              _gridBloc
                                  .add(GridLoadRequested(anchorDate: date));
                            },
                          )
                        : WeekRangeSelector(
                            weekStart: grid.weekStart,
                            onPrev: () =>
                                _gridBloc.add(const GridWeekShifted(-1)),
                            onNext: () =>
                                _gridBloc.add(const GridWeekShifted(1)),
                            onToday: () => _gridBloc
                                .add(const GridCurrentWeekRequested()),
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ServiceTabs(
                    selected: grid.service,
                    onSelected: (svc) =>
                        _gridBloc.add(GridServiceSelected(svc)),
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
                      // Тап по дню недели → открыть этот день целиком
                      // (переключение сетки в режим «день» на эту дату).
                      onDayTap: (date) => setState(() {
                        _selectedDate = date;
                        _viewMode = _MenuViewMode.day;
                      }),
                      // Тап по пустой ячейке → добавить блюдо. Только менеджер
                      // (шеф план не создаёт) → у шефа «＋» не показываем.
                      onAddTap:
                          _role == UserRole.manager ? _onAddEmpty : null,
                    ),
                  ),
              ],
            ),
          );
        },
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

  /// Дата в центре видимой части ленты — по ней показываем месяц в шапке.
  late DateTime _centerDate = widget.selectedDate;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _DayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateFormatUtil.isSameDay(
      oldWidget.selectedDate,
      widget.selectedDate,
    )) {
      _centerDate = widget.selectedDate;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Обновляет месяц в шапке по центральной дате при прокрутке ленты.
  void _onScroll() {
    if (!_controller.hasClients) return;
    final center = _controller.offset +
        _controller.position.viewportDimension / 2 -
        AppSpacing.sm;
    final idx = (center / (_chipWidth + _sep))
        .floor()
        .clamp(0, widget.dates.length - 1);
    final d = widget.dates[idx];
    if (d.month != _centerDate.month || d.year != _centerDate.year) {
      setState(() => _centerDate = d);
    }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, 4),
          child: Text(
            DateFormatUtil.formatMonthYear(
                _centerDate, context.locale.toString()),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        SizedBox(
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
        ),
      ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_grid_model.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/presentation/providers/menu_dashboard_notifier.dart';
import 'package:mezzome/features/dishes/presentation/providers/production_grid_notifier.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/menu_dashboard_app_bar_title.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/production_grid_table.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/service_tabs.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/week_range_selector.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/tech_card_editor_sheet.dart';

/// §6.1 — меню-борд: недельная сетка `/chef/production-plans/grid`,
/// тап по блюду → техкарта снизу. На экране только недельный селектор,
/// табы приёма пищи и таблица.
class DishesScreen extends ConsumerStatefulWidget {
  const DishesScreen({super.key});

  @override
  ConsumerState<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends ConsumerState<DishesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productionGridNotifierProvider.notifier).load();
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice)),
      );
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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: AppSpacing.sm,
        title: MenuDashboardAppBarTitle(signature: signature),
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
                child: WeekRangeSelector(
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
            SliverToBoxAdapter(
              child: ProductionGridTable(
                rows: grid.rows,
                days: grid.days,
                serviceTitle: grid.grid?.serviceTypeTitle,
                showFinancials: showFinancials,
                onItemTap: (item, date) => _openGridDishSheet(
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

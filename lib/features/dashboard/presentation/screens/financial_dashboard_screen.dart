import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/responsive/form_factor.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/money_format.dart';
import 'package:mezzome/features/branches/domain/models/object_finance.dart';
import 'package:mezzome/features/branches/presentation/blocs/branches_bloc.dart';
import 'package:mezzome/features/financial/domain/models/financial_dashboard.dart';
import 'package:mezzome/features/financial/presentation/blocs/financial_bloc.dart';
import 'package:mezzome/features/nutrition/domain/models/nutrition_dashboard.dart';
import 'package:mezzome/features/nutrition/presentation/blocs/nutrition_bloc.dart';
import 'package:mezzome/features/warehouse/domain/models/warehouse_dashboard.dart';
import 'package:mezzome/features/warehouse/presentation/blocs/warehouse_bloc.dart';

/// Вкладка «Финансы»: сегменты Обзор · Объекты · Питание · Склад — все на BLoC.
class FinancialDashboardScreen extends StatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  State<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState extends State<FinancialDashboardScreen> {
  /// Коды сегментов: 0 — «Обзор», 1 — «Объекты», 2 — «Склад», 3 — «Питание».
  /// Порядок вкладок задаётся в [_SegmentTabs]; по умолчанию открыт «Питание».
  int _segment = 3;

  /// Все сегменты — BLoC + get_it (новая архитектура). Bloc'и живут на время
  /// экрана; единый фильтр периода синхронизируется между сегментами.
  late final FinancialBloc _financialBloc =
      sl<FinancialBloc>()..add(const FinancialRequested());
  late final WarehouseBloc _warehouseBloc =
      sl<WarehouseBloc>()..add(const WarehouseRequested());
  late final BranchesBloc _branchesBloc =
      sl<BranchesBloc>()..add(const BranchesRequested());
  late final NutritionBloc _nutritionBloc =
      sl<NutritionBloc>()..add(const NutritionRequested());

  @override
  void dispose() {
    _financialBloc.close();
    _warehouseBloc.close();
    _branchesBloc.close();
    _nutritionBloc.close();
    super.dispose();
  }

  String _periodOf(int seg) {
    switch (seg) {
      case 1:
        return _branchesBloc.state.period;
      case 2:
        return _warehouseBloc.state.period;
      case 3:
        return _nutritionBloc.state.period;
      default:
        return _financialBloc.state.period;
    }
  }

  void _setPeriodOf(int seg, String period) {
    switch (seg) {
      case 1:
        _branchesBloc.add(BranchesPeriodChanged(period));
        break;
      case 2:
        _warehouseBloc.add(WarehousePeriodChanged(period));
        break;
      case 3:
        _nutritionBloc.add(NutritionPeriodChanged(period));
        break;
      default:
        _financialBloc.add(FinancialPeriodChanged(period));
    }
  }

  void _onSegment(int value) {
    if (value == _segment) return;
    // Держим единый фильтр периода между сегментами.
    _setPeriodOf(value, _periodOf(_segment));
    setState(() => _segment = value);
  }

  void _refreshActive() {
    switch (_segment) {
      case 1:
        _branchesBloc.add(const BranchesRefreshed());
        break;
      case 2:
        _warehouseBloc.add(const WarehouseRefreshed());
        break;
      case 3:
        _nutritionBloc.add(const NutritionRefreshed());
        break;
      default:
        _financialBloc.add(const FinancialRefreshed());
    }
  }

  Widget _body() {
    switch (_segment) {
      case 1:
        return BlocProvider.value(
          value: _branchesBloc,
          child: const _ObjectsView(),
        );
      case 2:
        return BlocProvider.value(
          value: _warehouseBloc,
          child: const _WarehouseView(),
        );
      case 3:
        return BlocProvider.value(
          value: _nutritionBloc,
          child: const _NutritionView(),
        );
      default:
        return BlocProvider.value(
          value: _financialBloc,
          child: const _OverviewView(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('financeTabTitle'.tr()),
        actions: [
          IconButton(
            tooltip: 'refreshTooltip'.tr(),
            icon: const Icon(Icons.refresh),
            onPressed: _refreshActive,
          ),
        ],
      ),
      body: Column(
        children: [
          _SegmentTabs(segment: _segment, onSelected: _onSegment),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

/// Сегмент «Обзор» — главный финансовый дашборд (P&L) из `GET /dashboard`.
/// На новой архитектуре: BLoC + get_it.
class _OverviewView extends StatelessWidget {
  const _OverviewView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FinancialBloc>();
    return BlocBuilder<FinancialBloc, FinancialState>(
      builder: (context, state) {
        void onPeriod(String p) => bloc.add(FinancialPeriodChanged(p));
        final data = state.data;

        if (data == null) {
          if (state.status == FinancialStatus.failure) {
            return _ErrorView(
              error: state.error ?? '',
              onRetry: () => bloc.add(const FinancialRefreshed()),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _PeriodTabs(period: state.period, onSelected: onPeriod),
            if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                color: ThemePalette.accent(context),
                onRefresh: () async => bloc.add(const FinancialRefreshed()),
                child: _Content(data: data),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Сегмент «Объекты» — P&L по филиалам (`GET /dashboard/branches`).
/// На новой архитектуре: BLoC + get_it, presentation зависит от domain.
class _ObjectsView extends StatelessWidget {
  const _ObjectsView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BranchesBloc>();
    return BlocBuilder<BranchesBloc, BranchesState>(
      builder: (context, state) {
        void onPeriod(String p) => bloc.add(BranchesPeriodChanged(p));

        if (state.result == null) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              _PeriodTabs(period: state.period, onSelected: onPeriod),
              Expanded(
                child: _EmptyView(
                  message: 'branchEmpty'.tr(),
                  onRetry: () => bloc.add(const BranchesRefreshed()),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _PeriodTabs(period: state.period, onSelected: onPeriod),
            _BranchChips(
              objects: state.objects,
              selectedId: state.selectedId,
              onSelected: (id) => bloc.add(BranchSelected(id)),
            ),
            if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                color: ThemePalette.accent(context),
                onRefresh: () async => bloc.add(const BranchesRefreshed()),
                child: _BranchesContent(
                  objects: state.objects,
                  selectedId: state.selectedId,
                  money: state.canViewMoney,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data});

  final FinancialDashboard data;

  @override
  Widget build(BuildContext context) {
    final money = data.canViewMoney;
    final p = data.profitability;
    final s = data.sales;
    final c = data.costs;
    final pay = data.payments;

    String m(double v) => money ? formatTenge(v) : '—';
    String sm(double v) => money ? formatSignedTenge(v) : '—';

    final foodColor = _foodCostColor(c.foodCostPct);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _KpiWrap(
          cards: [
            _Kpi(label: 'kpiRevenue'.tr(), value: m(s.recognizedRevenue)),
            _Kpi(
              label: 'kpiGrossProfit'.tr(),
              value: sm(p.grossProfit),
              valueColor: money ? _profitColor(p.grossProfit) : null,
              sub: formatPercent(p.grossMarginPct),
            ),
            _Kpi(
              label: 'kpiOperatingProfit'.tr(),
              value: sm(p.operatingProfit),
              valueColor: money ? _profitColor(p.operatingProfit) : null,
              sub: formatPercent(p.operatingMarginPct),
            ),
            _Kpi(
              label: 'kpiFoodCost'.tr(),
              value: formatPercent(c.foodCostPct),
              valueColor: foodColor,
            ),
            _Kpi(label: 'kpiAvgCheck'.tr(), value: m(s.averageOrderValue)),
            _Kpi(
              label: 'kpiCollection'.tr(),
              value: formatPercent(pay.collectionRatePct),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'secOperations'.tr(),
          child: Column(
            children: [
              _Line(
                label: 'secOrders'.tr(),
                value:
                    '${s.completedOrders} / ${s.openOrders} / ${s.cancelledOrders}',
                hint: 'secOrdersHint'.tr(),
              ),
              _Line(label: 'secDiscounts'.tr(), value: m(s.discountsTotal)),
              _Line(
                label: 'secServiceCharge'.tr(),
                value: m(s.serviceChargeTotal),
              ),
              _Line(label: 'secPending'.tr(), value: m(pay.pendingPayments)),
              _Line(label: 'secRefunds'.tr(), value: m(pay.refundsTotal)),
              _Line(label: 'secCash'.tr(), value: m(pay.cashPayments)),
              _Line(label: 'secCashless'.tr(), value: m(pay.cashlessPayments)),
              _Line(
                label: 'secLosses'.tr(),
                value: m(c.lossesTotal),
                hint: 'secLossesHint'.tr(),
              ),
              _Line(label: 'secCogs'.tr(), value: m(c.cogs)),
              _Line(label: 'secOpex'.tr(), value: m(c.opexTotal)),
              _Line(
                label: 'secInventoryPurchases'.tr(),
                value: m(c.inventoryPurchases),
                hint: 'secInventoryPurchasesHint'.tr(),
              ),
              _Line(
                label: 'secInventoryConsumption'.tr(),
                value: m(c.inventoryConsumption),
              ),
            ],
          ),
        ),
        if (data.daily.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'secDaily'.tr(),
            child: _DailyBars(daily: data.daily, money: money),
          ),
        ],
        if (data.expenseCategories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'secExpenseStructure'.tr(),
            child: _CategoryBars(
              categories: data.expenseCategories,
              money: money,
            ),
          ),
        ],
        if (data.paymentMethods.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'secPaymentMethods'.tr(),
            child: Column(
              children: [
                for (final pm in data.paymentMethods)
                  _Line(
                    label: pm.paymentType.isEmpty ? '—' : pm.paymentType,
                    value: m(pm.netAmount),
                    hint: 'secCountHint'.tr(namedArgs: {'count': '${pm.count}'}),
                  ),
              ],
            ),
          ),
        ],
        if (data.topItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'secTopItems'.tr(),
            child: Column(
              children: [
                for (final t in data.topItems.take(10))
                  _Line(
                    label: t.name,
                    value: m(t.revenue),
                    hint: money ? formatPercent(t.grossMarginPct) : '',
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _DataQualityCard(quality: data.dataQuality),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

Color _profitColor(double v) =>
    v >= 0 ? AppColors.profitGreen : AppColors.dangerRed;

Color _foodCostColor(double pct) {
  if (pct <= 0) return AppColors.textSecondary;
  if (pct <= 40) return AppColors.profitGreen;
  if (pct <= 55) return AppColors.warningAmber;
  return AppColors.dangerRed;
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.period, required this.onSelected});

  final String period;
  final ValueChanged<String> onSelected;

  static const _items = [
    ('day', 'expensePeriodDay'),
    ('week', 'expensePeriodWeek'),
    ('month', 'expensePeriodMonth'),
    ('year', 'expensePeriodYear'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (final (value, key) in _items) ...[
            Expanded(
              child: _PeriodChip(
                label: key.tr(),
                selected: period == value,
                onTap: () => onSelected(value),
              ),
            ),
            if (value != 'year') const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    final accent = ThemePalette.accent(context);
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.12)
          : ThemePalette.surfaceCard(context),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? accent : ThemePalette.border(context),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? accent : ThemePalette.onSurfaceMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiWrap extends StatelessWidget {
  const _KpiWrap({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = (c.maxWidth / 180).floor().clamp(2, 6);
        const spacing = AppSpacing.sm;
        final width = (c.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
    this.accent,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;

  /// Цвет левой полоски-акцента (как в макете «Сводной»). null — без полоски.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ThemePalette.onSurfaceMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
        ],
      ),
    );
    if (accent == null) return card;
    // Левая цветная полоска-акцент.
    return Stack(
      children: [
        card,
        Positioned(
          left: 0,
          top: 8,
          bottom: 8,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            Text(
              hint!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.categories, required this.money});

  final List<FinCategory> categories;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    final sorted = [...categories]..sort((a, b) => b.amount.compareTo(a.amount));
    return Column(
      children: [
        for (final cat in sorted.where((e) => e.amount > 0)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _expenseLabel(cat.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      money ? formatTenge(cat.amount) : '—',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        formatPercent(cat.sharePct),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ThemePalette.onSurfaceMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (cat.sharePct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: ThemePalette.border(context),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Простой столбчатый график выручки по дням (без зависимостей).
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily, required this.money});

  final List<FinDailyPoint> daily;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final maxRev = daily.fold<double>(
      0,
      (m, d) => d.recognizedRevenue > m ? d.recognizedRevenue : m,
    );
    final muted = ThemePalette.onSurfaceMuted(context);
    final n = daily.length;
    // На широких периодах (месяц/год) столбики узкие: подписи сумм над каждым
    // не помещаются и наезжают друг на друга — показываем их только когда
    // столбцов немного. Даты тоже прореживаем.
    final showValues = money && n <= 10;
    final labelEvery = n <= 16 ? 1 : (n / 10).ceil();
    final horizontalPad = n > 16 ? 1.0 : 2.0;

    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < daily.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showValues)
                      Text(
                        _short(daily[i].recognizedRevenue),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(fontSize: 8, color: muted),
                      ),
                    if (showValues) const SizedBox(height: 2),
                    Container(
                      height: maxRev <= 0
                          ? 2
                          : (90 * (daily[i].recognizedRevenue / maxRev))
                                .clamp(2, 90),
                      decoration: BoxDecoration(
                        color: daily[i].operatingProfit >= 0
                            ? AppColors.profitGreen
                            : AppColors.dangerRed,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 12,
                      child: i % labelEvery == 0
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _dayLabel(daily[i].date),
                                style: TextStyle(fontSize: 9, color: muted),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  static String _dayLabel(String date) {
    final d = DateTime.tryParse(date);
    return d == null ? '' : '${d.day}';
  }
}

class _DataQualityCard extends StatelessWidget {
  const _DataQualityCard({required this.quality});

  final FinDataQuality quality;

  @override
  Widget build(BuildContext context) {
    final pct = quality.overallCompletenessPct;
    final color = pct >= 95
        ? AppColors.profitGreen
        : (pct >= 80 ? AppColors.warningAmber : AppColors.dangerRed);
    final hasWarnings = quality.warnings.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'dataQualityTitle'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatPercent(pct),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _CoverageRow(
            label: 'dqRecipeCoverage'.tr(),
            pct: quality.recipeCoveragePct,
            total: quality.activeMenuItems,
            missing: quality.menuItemsWithoutRecipe,
          ),
          _CoverageRow(
            label: 'dqCostCoverage'.tr(),
            pct: quality.costCoveragePct,
            total: quality.completedOrderItems,
            missing: quality.orderItemsWithoutCost,
          ),
          _CoverageRow(
            label: 'dqReceiptCoverage'.tr(),
            pct: quality.receiptCostCoveragePct,
            total: quality.acceptedReceiptItems,
            missing: quality.receiptItemsWithoutCost,
          ),
          if (hasWarnings) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final w in quality.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppColors.warningAmber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _warningLabel(w),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ThemePalette.onSurfaceMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'dataQualityOk'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Строка покрытия в карточке качества данных: процент + абсолютные счётчики.
///
/// Гайд §6: рядом с процентом всегда показываем счётчики. `100%` при `total=0`
/// означает «нет данных для проверки», а не подтверждённое качество.
class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.label,
    required this.pct,
    required this.total,
    required this.missing,
  });

  final String label;
  final double pct;
  final int total;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final noData = total <= 0;
    final color = noData
        ? ThemePalette.onSurfaceMuted(context)
        : (pct >= 95
              ? AppColors.profitGreen
              : (pct >= 80 ? AppColors.warningAmber : AppColors.dangerRed));
    final muted = ThemePalette.onSurfaceMuted(context);
    final detail = noData
        ? 'dqNoData'.tr()
        : 'dqCoverageCount'.tr(
            namedArgs: {
              'ok': '${total - missing}',
              'total': '$total',
            },
          );

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            detail,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: muted),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              noData ? '—' : formatPercent(pct),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 44,
              color: ThemePalette.onSurfaceMuted(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'dashboardLoadError'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('retryButton'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Сегмент «Питание» — «Сводная по питанию» (`GET /dashboard/nutrition`).
/// Инсайт-первый экран: сверху вывод (что/почему/действие), затем KPI и детали.
/// Режим Менеджер (причины отклонений) / Овнер (только итоги) переключается
/// мгновенно и меняет глубину деталей.
class _NutritionView extends StatefulWidget {
  const _NutritionView();

  @override
  State<_NutritionView> createState() => _NutritionViewState();
}

class _NutritionViewState extends State<_NutritionView> {
  /// true — Менеджер (видит причины/состав/инспектора), false — Овнер (итоги).
  bool _managerMode = true;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NutritionBloc>();
    return BlocBuilder<NutritionBloc, NutritionState>(
      builder: (context, state) {
        void onPeriod(String p) => bloc.add(NutritionPeriodChanged(p));
        final data = state.data;

        if (data == null) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              _PeriodTabs(period: state.period, onSelected: onPeriod),
              Expanded(
                child: _EmptyView(
                  message: 'whUnavailable'.tr(),
                  onRetry: () => bloc.add(const NutritionRefreshed()),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: _ModeToggle(
                managerMode: _managerMode,
                onChanged: (v) => setState(() => _managerMode = v),
              ),
            ),
            _PeriodTabs(period: state.period, onSelected: onPeriod),
            if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                color: ThemePalette.accent(context),
                onRefresh: () async => bloc.add(const NutritionRefreshed()),
                child: _NutritionContent(data: data, managerMode: _managerMode),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Переключатель режима Менеджер | Овнер (pill-сегмент).
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.managerMode, required this.onChanged});

  final bool managerMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    Widget cell(String label, bool isManager) {
      final selected = managerMode == isManager;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(isManager),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : ThemePalette.onSurfaceMuted(context),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 3),
        border: Border.all(color: ThemePalette.border(context)),
      ),
      child: Row(
        children: [
          cell('nutModeManager'.tr(), true),
          cell('nutModeOwner'.tr(), false),
        ],
      ),
    );
  }
}

class _NutritionContent extends StatelessWidget {
  const _NutritionContent({required this.data, required this.managerMode});

  final NutritionDashboard data;
  final bool managerMode;

  @override
  Widget build(BuildContext context) {
    final money = data.canViewMoney;
    final s = data.summary;
    String m(double v) => money ? formatTenge(v) : '—';

    final daysWithData = data.daily.where((d) => d.mealsServed > 0).toList();

    final breakfast = data.mealByCode('BREAKFAST');
    final lunch = data.mealByCode('LUNCH');
    final dinner = data.mealByCode('DINNER');

    String mealSub(NutritionMealPeriod? mp) =>
        mp == null ? '' : formatPercent(mp.sharePct);
    Widget mealKpi(String fallback, NutritionMealPeriod? mp) => _Kpi(
          label: (mp != null && mp.name.isNotEmpty) ? mp.name : fallback.tr(),
          value: m(mp?.totalCost ?? 0),
          sub: mealSub(mp),
        );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 1. KPI-ряд (как в «Сводной»): всего · завтрак/обед/ужин (доля) ·
        //    СРМ ужина · прогноз.
        _KpiWrap(
          cards: [
            _Kpi(
              label: 'nutTotal'.tr(),
              value: m(s.totalCost),
              sub: '${'nutVsPrev'.tr()} ${_changeLabel(s.changePct)}',
              valueColor:
                  money ? _changeColor(s.changePct, lessIsGood: true) : null,
              accent: AppColors.profitGreen,
            ),
            mealKpi('nutBreakfast', breakfast),
            mealKpi('nutLunch', lunch),
            mealKpi('nutDinner', dinner),
            _Kpi(
              label: 'nutCpmDinner'.tr(),
              value: m(dinner?.averageCostPerMeal ?? s.averageCostPerMeal),
            ),
            if (data.forecast != null)
              _Kpi(
                label: 'nutForecast'.tr(),
                value: m(data.forecast!.projectedCost),
                sub: 'nutConfidence'.tr(
                  namedArgs: {
                    'pct': formatPercent(data.forecast!.confidencePct),
                  },
                ),
                accent: AppColors.warningAmber,
              ),
          ],
        ),

        // 2. Таблица по дням: приёмы + СРМ ужина + затраты + Δ + статус.
        if (daysWithData.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'nutByDay'.tr(),
            child: _NutritionDailyTable(data: data, days: daysWithData, money: money),
          ),
        ],

        // 3. Плашки INSPECTOR / ANALYST (только в режиме Менеджер).
        if (managerMode)
          for (final group in ['inspector', 'analyst'])
            if (data.insights.any((i) => i.source == group)) ...[
              const SizedBox(height: AppSpacing.md),
              _InsightsCard(
                source: group,
                insights:
                    data.insights.where((i) => i.source == group).toList(),
              ),
            ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Таблица по дням: дата · затраты дня · СРМ · Δ к ср. · статус.
class _NutritionDailyTable extends StatelessWidget {
  const _NutritionDailyTable({
    required this.data,
    required this.days,
    required this.money,
  });

  final NutritionDashboard data;
  final List<NutritionDay> days;
  final bool money;

  String _m(double v) => money ? formatTenge(v) : '—';

  double _sumMeal(String code) {
    var t = 0.0;
    for (final d in days) {
      t += d.mealByCode(code)?.totalCost ?? 0;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);

    // Цвета групп приёмов (как в макете): завтрак — лайм, обед — голубой,
    // ужин — красный, итог — лайм.
    final lime = AppColors.profitGreen;
    const blue = Color(0xFF4AA8FF);
    final red = AppColors.dangerRed;
    final border = ThemePalette.border(context);

    // Флексы колонок — общие для шапки и строк, чтобы всё было выровнено.
    const fDay = 22, fSum = 18, fCpm = 15, fTotal = 20, fDelta = 13, fStatus = 20;
    const fTotalGroup = fCpm + fTotal + fDelta + fStatus;

    Widget txt(String s, {Color? color, FontWeight? w, TextStyle? base}) => Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (base ?? theme.textTheme.bodySmall)
              ?.copyWith(color: color, fontWeight: w),
        );

    Widget cellRight(int flex, Widget child) =>
        Expanded(flex: flex, child: Align(alignment: Alignment.centerRight, child: child));
    Widget cellLeft(int flex, Widget child) =>
        Expanded(flex: flex, child: Align(alignment: Alignment.centerLeft, child: child));
    Widget cellCenter(int flex, Widget child) =>
        Expanded(flex: flex, child: Align(alignment: Alignment.center, child: child));

    Widget money(double v, {bool bold = false}) =>
        txt(_m(v), w: bold ? FontWeight.w700 : FontWeight.w400);

    Widget group(int flex, String key, Color dot) => Expanded(
          flex: flex,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: txt(key.tr(),
                    color: muted, w: FontWeight.w700,
                    base: theme.textTheme.labelSmall),
              ),
            ],
          ),
        );

    Widget headTxt(String key) => txt(key.tr(),
        color: muted, base: theme.textTheme.labelSmall);

    final dinnerAvg = data.mealByCode('DINNER')?.averageCostPerMeal ??
        data.summary.averageCostPerMeal;

    Widget dataRowFor(NutritionDay d, bool stripe) {
      return Container(
        color: stripe
            ? ThemePalette.onSurface(context).withValues(alpha: 0.03)
            : null,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            cellLeft(fDay, txt(_dayRu(d.date))),
            cellRight(fSum, money(d.mealByCode('BREAKFAST')?.totalCost ?? 0)),
            cellRight(fSum, money(d.mealByCode('LUNCH')?.totalCost ?? 0)),
            cellRight(fSum, money(d.mealByCode('DINNER')?.totalCost ?? 0)),
            cellRight(fCpm, money(d.mealByCode('DINNER')?.averageCostPerMeal ?? 0)),
            cellRight(fTotal, money(d.totalCost, bold: true)),
            cellRight(
              fDelta,
              txt(_deltaLabel(d.deviationPct),
                  color: _deltaColor(d.deviationPct), w: FontWeight.w700),
            ),
            cellCenter(fStatus, _StatusPill(status: d.status)),
          ],
        ),
      );
    }

    final table = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Уровень 1 — группы приёмов с цветными точками.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              const Expanded(flex: fDay, child: SizedBox()),
              group(fSum, 'nutGrpBreakfast', lime),
              group(fSum, 'nutGrpLunch', blue),
              group(fSum, 'nutGrpDinner', red),
              group(fTotalGroup, 'nutGrpTotal', lime),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Уровень 2 — подписи колонок.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              cellLeft(fDay, headTxt('nutColDay')),
              cellRight(fSum, headTxt('nutColSum')),
              cellRight(fSum, headTxt('nutColLunch')),
              cellRight(fSum, headTxt('nutColSum')),
              cellRight(fCpm, headTxt('nutColCpm')),
              cellRight(fTotal, headTxt('nutColTotal')),
              cellRight(fDelta, headTxt('nutColDelta')),
              cellCenter(fStatus, headTxt('nutColStatus')),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, color: border),
        for (var i = 0; i < days.length; i++) dataRowFor(days[i], i.isOdd),
        Divider(height: 1, color: border),
        // ИТОГО.
        Container(
          color: ThemePalette.accent(context).withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: AppSpacing.xs),
          child: Row(
            children: [
              cellLeft(fDay, txt('nutTotalRow'.tr(), w: FontWeight.w700)),
              cellRight(fSum, money(_sumMeal('BREAKFAST'), bold: true)),
              cellRight(fSum, money(_sumMeal('LUNCH'), bold: true)),
              cellRight(fSum, money(_sumMeal('DINNER'), bold: true)),
              cellRight(fCpm, money(dinnerAvg, bold: true)),
              cellRight(fTotal, money(data.summary.totalCost, bold: true)),
              const Expanded(flex: fDelta, child: SizedBox()),
              cellCenter(
                fStatus,
                txt('nutDaysCount'.tr(namedArgs: {'n': '${days.length}'}),
                    color: muted, base: theme.textTheme.labelSmall),
              ),
            ],
          ),
        ),
      ],
    );

    // Тянем на всю ширину области (веб заполняет экран); на узком телефоне
    // фиксируем минимум и включаем горизонтальный скролл.
    return LayoutBuilder(
      builder: (context, c) {
        const minW = 680.0;
        final fits = c.maxWidth >= minW;
        final content = SizedBox(width: fits ? c.maxWidth : minW, child: table);
        if (fits) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        );
      },
    );
  }
}

/// Пилюля статуса дня: В НОРМЕ (лайм) / Внимание (амбер) / ДИСБАЛАНС (красный).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status) ?? ThemePalette.onSurfaceMuted(context);
    final label = switch (status) {
      'normal' => 'nutStatusOk',
      'warning' => 'nutStatusWarning',
      'imbalanced' => 'nutStatusImbalanced',
      _ => 'nutStatusOk',
    }
        .tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Дата «1 янв» (день + сокр. месяц) для таблицы питания.
String _dayRu(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return date;
  const months = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
  final mi = (d.month - 1).clamp(0, 11);
  return '${d.day} ${months[mi]}';
}

/// Блок инсайтов INSPECTOR/ANALYST (текст бэка не пересчитываем — гайд §20).
class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.source, required this.insights});

  final String source;
  final List<NutritionInsight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInspector = source == 'inspector';
    final accent = isInspector ? AppColors.dangerRed : ThemePalette.accent(context);
    return Container(
      // Цветная рамка/тинт как в макете (красный INSPECTOR / лаймовый ANALYST).
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInspector
                    ? Icons.report_problem_outlined
                    : Icons.insights_outlined,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                (isInspector ? 'nutInspector' : 'nutAnalyst').tr(),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: accent),
              ),
            ],
          ),
          for (final i in insights) ...[
            const SizedBox(height: AppSpacing.xs),
            if (i.title.isNotEmpty)
              Text(
                i.title,
                style:
                    theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            if (i.message.isNotEmpty)
              Text(
                i.message,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: ThemePalette.onSurfaceMuted(context)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Цвет по статусу питания: норма/внимание/дисбаланс.
Color? _statusColor(String status) {
  switch (status) {
    case 'normal':
      return AppColors.profitGreen;
    case 'warning':
      return AppColors.warningAmber;
    case 'imbalanced':
      return AppColors.dangerRed;
    default:
      return null;
  }
}

String _changeLabel(double pct) =>
    '${pct > 0 ? '+' : ''}${formatPercent(pct)}';

String _deltaLabel(double pct) =>
    pct == 0 ? '0%' : '${pct > 0 ? '+' : ''}${formatPercent(pct)}';

Color _deltaColor(double pct) {
  if (pct > 5) return AppColors.dangerRed;
  if (pct < -5) return AppColors.profitGreen;
  return AppColors.warningAmber;
}

Color _changeColor(double pct, {bool lessIsGood = false}) {
  if (pct == 0) return AppColors.textSecondary;
  final good = lessIsGood ? pct < 0 : pct > 0;
  return good ? AppColors.profitGreen : AppColors.dangerRed;
}

/// Сегмент «Склад» — складской дашборд (`GET /dashboard/warehouse`).
/// Эталон новой архитектуры: BLoC + get_it, presentation зависит от domain.
class _WarehouseView extends StatelessWidget {
  const _WarehouseView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<WarehouseBloc>();
    return BlocBuilder<WarehouseBloc, WarehouseState>(
      builder: (context, state) {
        void onPeriod(String p) => bloc.add(WarehousePeriodChanged(p));
        final data = state.data;

        if (data == null) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // best-effort: недоступно/нет данных — мягкое состояние, не краш.
          return Column(
            children: [
              _PeriodTabs(period: state.period, onSelected: onPeriod),
              Expanded(
                child: _EmptyView(
                  message: 'whUnavailable'.tr(),
                  onRetry: () => bloc.add(const WarehouseRefreshed()),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _PeriodTabs(period: state.period, onSelected: onPeriod),
            if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                color: ThemePalette.accent(context),
                onRefresh: () async => bloc.add(const WarehouseRefreshed()),
                child: _WarehouseContent(data: data),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WarehouseContent extends StatelessWidget {
  const _WarehouseContent({required this.data});

  final WarehouseDashboard data;

  @override
  Widget build(BuildContext context) {
    final money = data.canViewMoney;
    final s = data.summary;
    String m(double v) => money ? formatTenge(v) : '—';

    final healthColor = s.stockHealthPct >= 80
        ? AppColors.profitGreen
        : (s.stockHealthPct >= 50
              ? AppColors.warningAmber
              : AppColors.dangerRed);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _KpiWrap(
          cards: [
            _Kpi(label: 'whPurchases'.tr(), value: m(s.inventoryPurchases)),
            _Kpi(label: 'whConsumption'.tr(), value: m(s.inventoryConsumption)),
            _Kpi(label: 'whFoodCost'.tr(), value: m(s.foodCost)),
            _Kpi(label: 'whNonFood'.tr(), value: m(s.nonFoodSpend)),
            _Kpi(
              label: 'whWaste'.tr(),
              value: m(s.wasteLoss),
              valueColor: money && s.wasteLoss > 0 ? AppColors.dangerRed : null,
            ),
            _Kpi(
              label: 'whHealth'.tr(),
              value: formatPercent(s.stockHealthPct),
              valueColor: healthColor,
            ),
            _Kpi(
              label: 'whLowStock'.tr(),
              value: '${s.lowStockCount}',
              valueColor: s.lowStockCount > 0 ? AppColors.warningAmber : null,
            ),
          ],
        ),
        if (data.budgetVariance.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'whBudgetVsFact'.tr(),
            child: Column(
              children: [
                for (final b in data.budgetVariance)
                  _BudgetVarianceRow(item: b, money: money),
              ],
            ),
          ),
        ],
        if (data.lowStockItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'whLowStockTitle'.tr(),
            child: Column(
              children: [
                for (final i in data.lowStockItems) _LowStockRow(item: i),
              ],
            ),
          ),
        ],
        if (data.mealCostRows.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'whMealCost'.tr(),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(flex: 3, child: SizedBox()),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'whMealTotal'.tr(),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ThemePalette.onSurfaceMuted(context),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'whMealCpm'.tr(),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ThemePalette.onSurfaceMuted(context),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'whSwipes'.tr(),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ThemePalette.onSurfaceMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
                for (final r in data.mealCostRows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            r.dateLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            m(r.totalCost),
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            m(r.costPerMeal),
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${r.swipes}',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: ThemePalette.onSurfaceMuted(context),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (data.categoryChart.where((c) => c.value > 0).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'whCategories'.tr(),
            child: _WarehouseCategoryBars(items: data.categoryChart, money: money),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Строка «бюджет vs факт»: факт, цель, отклонение (перерасход — красным).
class _BudgetVarianceRow extends StatelessWidget {
  const _BudgetVarianceRow({required this.item, required this.money});

  final WarehouseBudgetVariance item;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final overspent = item.delta > 0;
    final color = overspent ? AppColors.dangerRed : AppColors.profitGreen;
    final muted = ThemePalette.onSurfaceMuted(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _warehouseCategoryLabel(item.category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Text(
                money
                    ? '${formatTenge(item.actual)} / ${formatTenge(item.target)}'
                    : '—',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  '${overspent ? '+' : ''}${formatPercent(item.deviationPct)}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.target <= 0
                  ? 1
                  : (item.actual / item.target).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: ThemePalette.border(context),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (!money)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                overspent ? 'whOverspend'.tr() : 'whWithinBudget'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Строка заканчивающегося остатка: critical красным / low амбер.
class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});

  final WarehouseLowStockItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isCritical ? AppColors.dangerRed : AppColors.warningAmber;
    final theme = Theme.of(context);
    String fmt(double v) {
      final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
      return item.unit.isEmpty ? s : '$s ${item.unit}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '${fmt(item.currentStock)} / ${fmt(item.minRequired)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ThemePalette.onSurfaceMuted(context),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            (item.isCritical ? 'whStatusCritical' : 'whStatusLow').tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Структура складских расходов по категориям (бар-чарт без зависимостей).
class _WarehouseCategoryBars extends StatelessWidget {
  const _WarehouseCategoryBars({required this.items, required this.money});

  final List<WarehouseCategoryChartItem> items;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    final positive = items.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = positive.fold<double>(0, (sum, e) => sum + e.value);
    return Column(
      children: [
        for (final c in positive) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _warehouseCategoryLabel(c.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      money ? formatTenge(c.value) : '—',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total <= 0 ? 0 : (c.value / total).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: ThemePalette.border(context),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Подпись складской категории (`food`, `janitorials`…).
String _warehouseCategoryLabel(String key) {
  final label = 'warehouseCategory.$key'.tr();
  return label == 'warehouseCategory.$key' ? key : label;
}

/// Мягкое пустое состояние (нет данных / раздел недоступен) с кнопкой повтора.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: ThemePalette.onSurfaceMuted(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('retryButton'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Переключатель разделов вкладки «Финансы» в виде вкладок с подчёркиванием
/// (как верхние Дашборд·Кухни·Официанты): ровный ряд на всю ширину, активный —
/// цветной текст + полоска-подчёркивание; общая базовая линия снизу.
class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({required this.segment, required this.onSelected});

  final int segment;
  final ValueChanged<int> onSelected;

  static const _items = [
    (3, 'finSegmentNutrition'),
    (0, 'finSegmentOverview'),
    (1, 'finSegmentObjects'),
    (2, 'finSegmentWarehouse'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    final base = ThemePalette.border(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: base)),
      ),
      child: Row(
        children: [
          for (final (value, key) in _items)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: segment == value ? accent : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    key.tr(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: segment == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: segment == value ? accent : muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Горизонтальные чипы объектов: All · Catering 1 · 2 · 3 …
class _BranchChips extends StatelessWidget {
  const _BranchChips({
    required this.objects,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ObjectFinance> objects;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final branches = objects.where((o) => !o.isAll).toList();
    if (branches.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          _Chip(
            label: 'branchAll'.tr(),
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final b in branches)
            _Chip(
              label: b.name.isEmpty ? '#${b.id}' : b.name,
              selected: selectedId == b.id,
              onTap: () => onSelected(b.id),
            ),
        ],
      ),
    );
  }
}

/// Чип (используется для объектов) — компактная горизонтальная версия.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    final accent = ThemePalette.accent(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.12)
            : ThemePalette.surfaceCard(context),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? accent : ThemePalette.border(context),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? accent : ThemePalette.onSurfaceMuted(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Список полноэкранных карточек P&L по объектам под выбранный чип.
class _BranchesContent extends StatelessWidget {
  const _BranchesContent({
    required this.objects,
    required this.selectedId,
    required this.money,
  });

  final List<ObjectFinance> objects;
  final int? selectedId;
  final bool money;

  /// Карточки под выбранный чип: «Все» → отдельные кейтеринги (карусель),
  /// иначе — выбранный объект. Фолбэк на агрегат, если отдельных нет.
  List<ObjectFinance> get _cards {
    if (selectedId != null) {
      return objects.where((o) => o.id == selectedId).toList();
    }
    final individual = objects.where((o) => !o.isAll).toList();
    return individual.isNotEmpty
        ? individual
        : objects; // только агрегат — показываем его
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    if (cards.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                'branchEmpty'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Веб/десктоп — сетка карточек во всю ширину; телефон — горизонтальная
    // карусель (видно ~1.5 карточки, как в макете).
    if (context.isCompact && cards.length > 1) {
      return LayoutBuilder(
        builder: (context, c) {
          final cardW = c.maxWidth * 0.82;
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final o in cards)
                Container(
                  width: cardW,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  alignment: Alignment.topCenter,
                  child: _BranchCard(object: o, money: money),
                ),
            ],
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, c) {
          // На широком экране — несколько карточек в ряд; одна карточка → одна
          // колонка. Карточки в ряду — равной высоты (IntrinsicHeight).
          final perRow = context.isExpanded
              ? (c.maxWidth / 380).floor().clamp(1, 3)
              : 1;
          const gap = AppSpacing.md;

          if (perRow == 1) {
            return Column(
              children: [
                for (final o in cards) ...[
                  _BranchCard(object: o, money: money),
                  const SizedBox(height: gap),
                ],
              ],
            );
          }

          final rows = <Widget>[];
          for (var i = 0; i < cards.length; i += perRow) {
            final slice = cards.skip(i).take(perRow).toList();
            rows.add(IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < perRow; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(
                      child: j < slice.length
                          ? _BranchCard(
                              object: slice[j], money: money, stretch: true)
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ));
            rows.add(const SizedBox(height: gap));
          }
          return Column(children: rows);
        },
      ),
    );
  }
}

/// Карточка P&L одного объекта кейтеринга (макет «Дашборд»): выручка,
/// себестоимость, список расходов и чистая прибыль (бирюзовая).
class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.object,
    required this.money,
    this.stretch = false,
  });

  final ObjectFinance object;
  final bool money;

  /// Растянуть карточку на всю высоту ряда (для веб-сетки равной высоты) и
  /// прижать «Чистую прибыль» к низу.
  final bool stretch;

  /// Бирюзовый акцент чистой прибыли из макета.
  static const _netTeal = Color(0xFF4FD1B5);

  /// Фиолетовая точка-маркер кейтеринга из макета.
  static const _dotViolet = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String m(double v) => money ? formatTenge(v) : '—';
    String sm(double v) => money ? formatSignedTenge(v) : '—';

    final title = (object.isAll ? 'branchAll'.tr() : object.name).toUpperCase();
    final expenses = [...object.expensesByCategory.entries]
      ..sort((a, b) => b.value.compareTo(a.value));
    final netColor = money
        ? (object.netProfit >= 0 ? _netTeal : AppColors.dangerRed)
        : ThemePalette.onSurface(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Заголовок: фиолетовая точка + имя кейтеринга.
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _dotViolet,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Line(label: 'branchRevenue'.tr(), value: m(object.revenue)),
          _Line(label: 'branchCogs'.tr(), value: m(object.cogs)),
          const Divider(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'branchExpenses'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final e in expenses.where((e) => e.value > 0))
            _Line(label: _expenseLabel(e.key), value: m(e.value)),
          if (stretch) const Spacer(),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'branchNetProfit'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                sm(object.netProfit),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: netColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Подпись категории расхода (те же ключи, что на экране «Расходы»).
String _expenseLabel(String key) {
  final label = 'expenseCategory.$key'.tr();
  return label == 'expenseCategory.$key' ? key : label;
}

/// Подпись предупреждения качества данных.
String _warningLabel(String code) {
  final label = 'dataQualityWarning.$code'.tr();
  return label == 'dataQualityWarning.$code' ? code : label;
}

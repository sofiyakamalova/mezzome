import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/money_format.dart';
import 'package:mezzome/features/dashboard/data/models/financial_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/nutrition_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/warehouse_dashboard_model.dart';
import 'package:mezzome/features/dashboard/presentation/providers/branches_dashboard_notifier.dart';
import 'package:mezzome/features/dashboard/presentation/providers/financial_dashboard_notifier.dart';
import 'package:mezzome/features/dashboard/presentation/providers/nutrition_dashboard_notifier.dart';
import 'package:mezzome/features/dashboard/presentation/providers/warehouse_dashboard_notifier.dart';

/// Вкладка «Финансы»: сегмент «Обзор» (общий P&L из `GET /dashboard`) и
/// «Объекты» (P&L по филиалам из `GET /dashboard/branches`).
class FinancialDashboardScreen extends ConsumerStatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  ConsumerState<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState
    extends ConsumerState<FinancialDashboardScreen> {
  /// 0 — «Обзор», 1 — «Объекты», 2 — «Склад».
  int _segment = 0;

  String _periodOf(int seg) {
    switch (seg) {
      case 1:
        return ref.read(branchesDashboardNotifierProvider.notifier).period;
      case 2:
        return ref.read(warehouseDashboardNotifierProvider.notifier).period;
      case 3:
        return ref.read(nutritionDashboardNotifierProvider.notifier).period;
      default:
        return ref.read(financialDashboardNotifierProvider.notifier).period;
    }
  }

  void _setPeriodOf(int seg, String period) {
    switch (seg) {
      case 1:
        ref.read(branchesDashboardNotifierProvider.notifier).setPeriod(period);
        break;
      case 2:
        ref.read(warehouseDashboardNotifierProvider.notifier).setPeriod(period);
        break;
      case 3:
        ref.read(nutritionDashboardNotifierProvider.notifier).setPeriod(period);
        break;
      default:
        ref.read(financialDashboardNotifierProvider.notifier).setPeriod(period);
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
        ref.read(branchesDashboardNotifierProvider.notifier).refresh();
        break;
      case 2:
        ref.read(warehouseDashboardNotifierProvider.notifier).refresh();
        break;
      case 3:
        ref.read(nutritionDashboardNotifierProvider.notifier).refresh();
        break;
      default:
        ref.read(financialDashboardNotifierProvider.notifier).refresh();
    }
  }

  Widget _body() {
    switch (_segment) {
      case 1:
        return const _ObjectsBody();
      case 2:
        return const _WarehouseBody();
      case 3:
        return const _NutritionBody();
      default:
        return const _OverviewBody();
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
class _OverviewBody extends ConsumerWidget {
  const _OverviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financialDashboardNotifierProvider);
    final notifier = ref.read(financialDashboardNotifierProvider.notifier);
    final data = async.valueOrNull;

    if (data == null) {
      return async.hasError
          ? _ErrorView(error: async.error!, onRetry: notifier.refresh)
          : const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _PeriodTabs(period: notifier.period, onSelected: notifier.setPeriod),
        if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            color: ThemePalette.accent(context),
            onRefresh: notifier.refresh,
            child: _Content(data: data),
          ),
        ),
      ],
    );
  }
}

/// Сегмент «Объекты» — P&L по филиалам (`GET /dashboard/branches`).
class _ObjectsBody extends ConsumerWidget {
  const _ObjectsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchesDashboardNotifierProvider);
    final notifier = ref.read(branchesDashboardNotifierProvider.notifier);
    final data = async.valueOrNull;

    if (data == null) {
      return async.hasError
          ? _ErrorView(error: async.error!, onRetry: notifier.refresh)
          : const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _PeriodTabs(period: notifier.period, onSelected: notifier.setPeriod),
        _BranchChips(
          objects: data.objects,
          selectedId: data.selectedId,
          onSelected: notifier.setBranch,
        ),
        if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            color: ThemePalette.accent(context),
            onRefresh: notifier.refresh,
            child: _BranchesContent(data: data),
          ),
        ),
      ],
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
  });

  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
        ],
      ),
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
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in daily)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      money ? _short(d.recognizedRevenue) : '',
                      maxLines: 1,
                      style: TextStyle(fontSize: 8, color: muted),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: maxRev <= 0
                          ? 2
                          : (90 * (d.recognizedRevenue / maxRev)).clamp(2, 90),
                      decoration: BoxDecoration(
                        color: d.operatingProfit >= 0
                            ? AppColors.profitGreen
                            : AppColors.dangerRed,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dayLabel(d.date),
                      style: TextStyle(fontSize: 9, color: muted),
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
class _NutritionBody extends ConsumerStatefulWidget {
  const _NutritionBody();

  @override
  ConsumerState<_NutritionBody> createState() => _NutritionBodyState();
}

class _NutritionBodyState extends ConsumerState<_NutritionBody> {
  /// true — Менеджер (видит причины/состав/инспектора), false — Овнер (итоги).
  bool _managerMode = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nutritionDashboardNotifierProvider);
    final notifier = ref.read(nutritionDashboardNotifierProvider.notifier);
    final data = async.valueOrNull;

    if (data == null) {
      if (async.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        children: [
          _PeriodTabs(period: notifier.period, onSelected: notifier.setPeriod),
          Expanded(
            child: _EmptyView(
              message: 'whUnavailable'.tr(),
              onRetry: notifier.refresh,
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
        _PeriodTabs(period: notifier.period, onSelected: notifier.setPeriod),
        if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            color: ThemePalette.accent(context),
            onRefresh: notifier.refresh,
            child: _NutritionContent(data: data, managerMode: _managerMode),
          ),
        ),
      ],
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
    final verdict = _NutritionVerdict.compute(data, daysWithData);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 1. ГЛАВНЫЙ ВЫВОД: что произошло / почему / что делать.
        _NutritionHeadline(verdict: verdict),
        const SizedBox(height: AppSpacing.md),
        // 2. KPI: общие расходы, СРМ, прогноз — сумма + тренд.
        _KpiWrap(
          cards: [
            _Kpi(
              label: 'nutTotal'.tr(),
              value: m(s.totalCost),
              sub: '${'nutVsPrev'.tr()} ${_changeLabel(s.changePct)}',
              valueColor: money ? _changeColor(s.changePct, lessIsGood: true) : null,
            ),
            _Kpi(
              label: 'nutCpm'.tr(),
              value: m(s.averageCostPerMeal),
              sub: '${'nutVsPrev'.tr()} ${_changeLabel(s.costPerMealChangePct)}',
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
              ),
          ],
        ),

        // 3. Детали — глубина зависит от режима.
        if (managerMode) ...[
          if (data.composition.where((c) => c.actualPct > 0).isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'nutComposition'.tr(),
              child: Column(
                children: [
                  for (final c in data.composition.where((c) => c.actualPct > 0))
                    _CompositionRow(item: c),
                ],
              ),
            ),
          ],
          for (final group in ['inspector', 'analyst'])
            if (data.insights.any((i) => i.source == group)) ...[
              const SizedBox(height: AppSpacing.md),
              _InsightsCard(
                source: group,
                insights:
                    data.insights.where((i) => i.source == group).toList(),
              ),
            ],
        ],

        if (daysWithData.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'nutByDay'.tr(),
            child: _NutritionDailyTable(days: daysWithData, money: money),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Готовый вывод по питанию: статус, самый затратный день, причина, действие.
/// Считается на фронте из дневных данных + целевых долей состава, чтобы
/// пользователь за 30 секунд видел «что/почему/что делать» без чтения таблиц.
class _NutritionVerdict {
  const _NutritionVerdict({
    required this.status,
    this.worstDay,
    this.worstDeviationPct = 0,
    this.causeGroupLabel,
    this.causeActualPct = 0,
    this.causeTargetPct = 0,
  });

  final String status; // normal | warning | imbalanced
  final NutritionDay? worstDay;
  final double worstDeviationPct;
  final String? causeGroupLabel;
  final double causeActualPct;
  final double causeTargetPct;

  bool get hasIssue => worstDay != null && status != 'normal';

  static _NutritionVerdict compute(
    NutritionDashboard data,
    List<NutritionDay> days,
  ) {
    if (days.isEmpty) {
      return const _NutritionVerdict(status: 'normal');
    }
    // Самый затратный день — максимальное положительное отклонение от среднего.
    final worst = days.reduce(
      (a, b) => b.deviationPct > a.deviationPct ? b : a,
    );

    // Причина: целевые доли food_group из composition[]; находим группу с
    // наибольшим превышением факта над нормой в этот день.
    final targets = <String, NutritionComposition>{
      for (final c in data.composition) c.foodGroup: c,
    };
    String? causeLabel;
    double causeActual = 0, causeTarget = 0, maxGap = 0;
    worst.composition.forEach((group, actual) {
      final t = targets[group];
      final target = t?.targetPct ?? 0;
      final gap = actual - target;
      if (gap > maxGap) {
        maxGap = gap;
        causeActual = actual;
        causeTarget = target;
        causeLabel = (t != null && t.label.isNotEmpty)
            ? t.label
            : _foodGroupLabel(group);
      }
    });

    return _NutritionVerdict(
      status: worst.status,
      worstDay: worst,
      worstDeviationPct: worst.deviationPct,
      causeGroupLabel: causeLabel,
      causeActualPct: causeActual,
      causeTargetPct: causeTarget,
    );
  }
}

/// Плашка-вывод сверху экрана питания.
class _NutritionHeadline extends StatelessWidget {
  const _NutritionHeadline({required this.verdict});

  final _NutritionVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(verdict.status) ?? AppColors.profitGreen;
    final ok = !verdict.hasIssue;
    final statusWord = ok
        ? 'nutStatusOk'.tr()
        : (verdict.status == 'imbalanced'
              ? 'nutStatusImbalanced'.tr()
              : 'nutStatusWarning'.tr());
    final dateLabel =
        verdict.worstDay == null ? '' : _dayMonth(verdict.worstDay!.date);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                statusWord.toUpperCase(),
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (ok)
            Text(
              'nutVerdictOk'.tr(),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            )
          else ...[
            Text(
              'nutVerdictWorst'.tr(
                namedArgs: {
                  'date': dateLabel,
                  'delta': _deltaLabel(verdict.worstDeviationPct),
                },
              ),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (verdict.causeGroupLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                'nutVerdictCause'.tr(
                  namedArgs: {
                    'group': verdict.causeGroupLabel!.toLowerCase(),
                    'actual': formatPercent(verdict.causeActualPct),
                    'target': formatPercent(verdict.causeTargetPct),
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.arrow_forward, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'nutVerdictAction'.tr(namedArgs: {'date': dateLabel}),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Color _changeColor(double pct, {bool lessIsGood = false}) {
  if (pct == 0) return AppColors.textSecondary;
  final good = lessIsGood ? pct < 0 : pct > 0;
  return good ? AppColors.profitGreen : AppColors.dangerRed;
}

/// Строка состава: доля факт vs цель, отклонение цветом по статусу.
class _CompositionRow extends StatelessWidget {
  const _CompositionRow({required this.item});

  final NutritionComposition item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(item.status) ?? ThemePalette.accent(context);
    final label = item.label.isNotEmpty
        ? item.label
        : _foodGroupLabel(item.foodGroup);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Text(
                '${formatPercent(item.actualPct)} / ${formatPercent(item.targetPct)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: (item.actualPct / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: ThemePalette.border(context),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Таблица по дням: дата · затраты дня · СРМ · Δ к ср. · статус.
class _NutritionDailyTable extends StatelessWidget {
  const _NutritionDailyTable({required this.days, required this.money});

  final List<NutritionDay> days;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    Widget head(String key, int flex, {TextAlign align = TextAlign.right}) =>
        Expanded(
          flex: flex,
          child: Text(
            key.tr(),
            textAlign: align,
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            head('nutColDay', 3, align: TextAlign.left),
            head('nutColTotal', 4),
            head('nutColCpm', 3),
            head('nutColDelta', 2),
          ],
        ),
        const SizedBox(height: 4),
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    _dayMonth(d.date),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    money ? formatTenge(d.totalCost) : '—',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    money ? formatTenge(d.averageCostPerMeal) : '—',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _deltaLabel(d.deviationPct),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _deltaColor(d.deviationPct),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
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

String _dayMonth(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return date;
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm';
}

/// Подпись food_group (`meat_fish`, `dairy`…).
String _foodGroupLabel(String key) {
  final label = 'foodGroup.$key'.tr();
  return label == 'foodGroup.$key' ? key : label;
}

/// Сегмент «Склад» — складской финансовый дашборд (`GET /dashboard/warehouse`).
class _WarehouseBody extends ConsumerWidget {
  const _WarehouseBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(warehouseDashboardNotifierProvider);
    final notifier = ref.read(warehouseDashboardNotifierProvider.notifier);
    final data = async.valueOrNull;

    if (data == null) {
      if (async.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      // best-effort: ошибка/недоступно/нет данных — мягкое состояние, не краш.
      return Column(
        children: [
          _PeriodTabs(period: notifier.period, onSelected: notifier.setPeriod),
          Expanded(
            child: _EmptyView(
              message: 'whUnavailable'.tr(),
              onRetry: notifier.refresh,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _PeriodTabs(period: notifier.period, onSelected: notifier.setPeriod),
        if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            color: ThemePalette.accent(context),
            onRefresh: notifier.refresh,
            child: _WarehouseContent(data: data),
          ),
        ),
      ],
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
                  _expenseLabel(item.category),
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
    (0, 'finSegmentOverview'),
    (1, 'finSegmentObjects'),
    (3, 'finSegmentNutrition'),
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
  const _BranchesContent({required this.data});

  final BranchesDashboardData data;

  @override
  Widget build(BuildContext context) {
    final visible = data.visible;
    if (visible.isEmpty) {
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final o in visible) ...[
          _BranchCard(object: o, money: data.canViewMoney),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Полноэкранная карточка P&L одного объекта (или агрегата «All»).
class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.object, required this.money});

  final ObjectFinance object;
  final bool money;

  @override
  Widget build(BuildContext context) {
    String m(double v) => money ? formatTenge(v) : '—';
    String sm(double v) => money ? formatSignedTenge(v) : '—';

    final title = object.isAll ? 'branchAll'.tr() : object.name;
    final expenses = [...object.expensesByCategory.entries]
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Section(
      title: title,
      child: Column(
        children: [
          _Line(
            label: 'branchRevenue'.tr(),
            value: m(object.revenue),
            hint: 'branchOrdersCount'.tr(
              namedArgs: {'count': '${object.ordersCount}'},
            ),
          ),
          _Line(label: 'branchCogs'.tr(), value: m(object.cogs)),
          _Line(
            label: 'branchGrossProfit'.tr(),
            value: sm(object.grossProfit),
            hint: formatPercent(object.grossMarginPct),
          ),
          const Divider(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'branchExpenses'.tr(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final e in expenses.where((e) => e.value > 0))
            _Line(label: _expenseLabel(e.key), value: m(e.value)),
          _Line(label: 'branchExpensesTotal'.tr(), value: m(object.expensesTotal)),
          if (object.isAll && (object.unallocatedOpex ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'branchUnallocatedHint'.tr(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ThemePalette.onSurfaceMuted(context),
                      ),
                    ),
                  ),
                  Text(
                    m(object.unallocatedOpex!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ThemePalette.onSurfaceMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'branchNetProfit'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                sm(object.netProfit),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: money ? _profitColor(object.netProfit) : null,
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

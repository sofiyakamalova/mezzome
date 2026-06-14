import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/money_format.dart';
import 'package:mezzome/features/dashboard/data/models/financial_dashboard_model.dart';
import 'package:mezzome/features/dashboard/presentation/providers/financial_dashboard_notifier.dart';

/// Экран «Обзор» — главный финансовый дашборд (P&L) из `GET /dashboard`.
class FinancialDashboardScreen extends ConsumerWidget {
  const FinancialDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financialDashboardNotifierProvider);
    final notifier = ref.read(financialDashboardNotifierProvider.notifier);
    final data = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('dashboardOverviewTitle'.tr()),
        actions: [
          IconButton(
            tooltip: 'refreshTooltip'.tr(),
            icon: const Icon(Icons.refresh),
            onPressed: notifier.refresh,
          ),
        ],
      ),
      body: data == null
          ? (async.hasError
                ? _ErrorView(error: async.error!, onRetry: notifier.refresh)
                : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                _PeriodTabs(
                  period: notifier.period,
                  onSelected: notifier.setPeriod,
                ),
                if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    color: ThemePalette.accent(context),
                    onRefresh: notifier.refresh,
                    child: _Content(data: data),
                  ),
                ),
              ],
            ),
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
              _Line(
                label: 'secLosses'.tr(),
                value: m(c.wasteTotal + c.writeOffsTotal),
                hint: 'secLossesHint'.tr(),
              ),
              _Line(label: 'secCogs'.tr(), value: m(c.cogs)),
              _Line(label: 'secOpex'.tr(), value: m(c.opexTotal)),
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

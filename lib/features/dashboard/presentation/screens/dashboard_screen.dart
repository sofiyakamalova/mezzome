import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';
import 'package:mezzome/features/dashboard/presentation/providers/dashboard_notifier.dart';
import 'package:mezzome/features/dashboard/presentation/providers/dashboard_state.dart';
import 'package:mezzome/features/dishes/data/models/plan_variance_model.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';

/// Денежная сумма с разбивкой по разрядам узким неразрывным пробелом: `509 657 400 ₸`.
String _money(double value) {
  final digits = value.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write(' ');
    }
    buf.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buf ₸';
}

/// Целое число с той же разбивкой по разрядам (для заказов).
String _count(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write(' ');
    }
    buf.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buf';
}

const _periods = ['day', 'week', 'month'];

String _periodLabel(String period) => switch (period) {
      'day' => 'periodDay'.tr(),
      'month' => 'periodMonth'.tr(),
      _ => 'periodWeek'.tr(),
    };

/// §6.3 — дашборд директора.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('dashboardTitle'.tr()),
        actions: [
          IconButton(
            tooltip: 'refreshTooltip'.tr(),
            icon: const Icon(Icons.refresh),
            onPressed: notifier.refresh,
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _DashboardError(error: error, onRetry: notifier.refresh),
        data: (state) {
          final data = state.data;
          return Column(
            children: [
              _PeriodTabs(
                selected: state.period,
                onSelected: notifier.setPeriod,
              ),
              if (state.isRefreshing)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: data == null
                    ? Center(child: Text('noData'.tr()))
                    : RefreshIndicator(
                        color: ThemePalette.accent(context),
                        onRefresh: notifier.refresh,
                        child: _DashboardContent(state: state),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Экран ошибки дашборда — показывает реальную причину (403 / код / сообщение),
/// а не общий текст, чтобы было видно, почему «пусто».
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    String detail;
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 403 || isApiForbidden(e)) {
        detail = 'dashboardForbidden'.tr();
      } else {
        detail = [
          if (status != null) 'HTTP $status',
          apiErrorDetails(e) ?? e.message ?? '',
        ].where((s) => s.isNotEmpty).join(' · ');
      }
    } else {
      detail = e.toString();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: ThemePalette.onSurfaceMuted(context)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'dashboardLoadError'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ThemePalette.onSurfaceMuted(context),
                    ),
              ),
            ],
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

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    final compliance = state.compliance?.summary;
    final planVsFact = state.planVsFact;
    final costPerHead = state.costPerHead;
    final variance = state.variance;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ManagerKpiGrid(data: data),
        if (compliance != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ComplianceSection(summary: compliance),
        ],
        if (planVsFact != null && planVsFact.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _PlanVsFactReportSection(report: planVsFact),
        ],
        if (costPerHead != null && costPerHead.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _CostPerHeadSection(report: costPerHead),
        ],
        if (variance != null && variance.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _VarianceSection(report: variance),
        ],
        // План vs факт текущего дня (отдельный источник — managerDayVariance).
        const _PlanVsFactSection(),
      ],
    );
  }
}

/// Карточка-секция с заголовком и иконкой (единый стиль блоков дашборда).
class _DashSection extends StatelessWidget {
  const _DashSection({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ThemePalette.onSurfaceMuted(context)),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Соответствие: халяль / КБЖУ / аллергены. Светофор по числу проблем.
class _ComplianceSection extends StatelessWidget {
  const _ComplianceSection({required this.summary});

  final ManagerComplianceSummary summary;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int count, IconData icon) {
      final ok = count == 0;
      final color = ok ? AppColors.profitGreen : AppColors.dangerRed;
      final theme = Theme.of(context);
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
              Text(
                ok ? 'dashOk'.tr() : '$count',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: ThemePalette.onSurfaceMuted(context)),
              ),
            ],
          ),
        ),
      );
    }

    return _DashSection(
      title: 'dashComplianceTitle'.tr(),
      icon: Icons.verified_outlined,
      child: Row(
        children: [
          tile('dashHalal'.tr(), summary.halalIssues, Icons.check_circle_outline),
          tile('dashNutrition'.tr(), summary.nutritionMissing, Icons.egg_alt_outlined),
          tile('dashAllergens'.tr(), summary.allergenMissing, Icons.warning_amber_outlined),
        ],
      ),
    );
  }
}

/// План vs факт по дням: суммарная воронка + строки по датам.
class _PlanVsFactReportSection extends StatelessWidget {
  const _PlanVsFactReportSection({required this.report});

  final ManagerPlanVsFactReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    var planned = 0, produced = 0, served = 0, leftover = 0;
    for (final i in report.items) {
      planned += i.plannedPortions;
      produced += i.producedPortions;
      served += i.servedPortions;
      leftover += i.leftoverPortions;
    }

    Widget stage(String label, int value, Color color) => Expanded(
          child: _HeroStat(
            label: label,
            value: _count(value),
            color: color,
          ),
        );

    return _DashSection(
      title: 'dashPlanVsFactReportTitle'.tr(),
      icon: Icons.insights_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              stage('dashPlanned'.tr(), planned, ThemePalette.onSurface(context)),
              stage('dashProduced'.tr(), produced, ThemePalette.accent(context)),
              stage('dashServed'.tr(), served, AppColors.profitGreen),
              stage('dashLeftover'.tr(), leftover,
                  leftover > 0 ? AppColors.warningAmber : muted),
            ],
          ),
          if (report.items.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: ThemePalette.border(context)),
            const SizedBox(height: AppSpacing.xs),
            for (final i in report.items.take(7))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        _shortDate(i.plannedDate),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        '${_count(i.plannedPortions)} → ${_count(i.servedPortions)}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        i.leftoverPortions > 0
                            ? '+${_count(i.leftoverPortions)}'
                            : '—',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: i.leftoverPortions > 0
                              ? AppColors.warningAmber
                              : muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Себестоимость на человека по дням (деньги по RBAC).
class _CostPerHeadSection extends StatelessWidget {
  const _CostPerHeadSection({required this.report});

  final ManagerCostPerHeadReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    final showMoney = report.showMoney;

    return _DashSection(
      title: 'dashCostPerHeadTitle'.tr(),
      icon: Icons.groups_outlined,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Text(
                  'dashMeals'.tr(),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'dashCostHead'.tr(),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
          for (final i in report.items.take(7))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(_shortDate(i.serviceDate),
                        style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _count(i.mealsServed),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      showMoney ? _money(i.costPerHead) : '—',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Отклонения по категориям (waste/process…).
class _VarianceSection extends StatelessWidget {
  const _VarianceSection({required this.report});

  final ManagerVarianceBreakdownReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    final showMoney = report.showMoney;

    return _DashSection(
      title: 'dashVarianceTitle'.tr(),
      icon: Icons.report_problem_outlined,
      child: Column(
        children: [
          for (final i in report.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      i.category ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _qty(i.lossQty),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      showMoney ? _money(i.costImpact) : '—',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: i.costImpact > 0
                            ? AppColors.dangerRed
                            : ThemePalette.onSurface(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// «2026-06-07T…» → «07.06». Пусто/неразбираемо → исходная строка.
String _shortDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d.$m';
}

/// Целое/дробное количество с единицей: «12», «12.5 кг».
String _qty(double value, [String? unit]) {
  final fixed = value.toStringAsFixed(2);
  final trimmed = fixed.contains('.')
      ? fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : fixed;
  return unit == null || unit.isEmpty ? trimmed : '$trimmed $unit';
}

/// «План vs факт» по плану текущего дня: сколько заложили vs сколько забрали.
/// Источник — `managerDayVarianceProvider`. Секция не показывается, если плана
/// за день нет / роль не manager / ручка недоступна.
class _PlanVsFactSection extends ConsumerWidget {
  const _PlanVsFactSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(managerDayVarianceProvider);
    final report = async.valueOrNull;
    if (report == null || report.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    final overspend = (report.variancePct ?? 0) > 5 || report.varianceCost > 0;
    final varianceColor =
        overspend ? AppColors.dangerRed : AppColors.profitGreen;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: ThemePalette.surfaceCard(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: ThemePalette.border(context), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'planVsFactTitle'.tr(),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'pvfPlanned'.tr(),
                    value: _money(report.theoreticalCost),
                  ),
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'pvfActual'.tr(),
                    value: _money(report.actualCost),
                  ),
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'pvfVariance'.tr(),
                    value: report.variancePct != null
                        ? '${report.variancePct!.toStringAsFixed(1)}%'
                        : _money(report.varianceCost),
                    color: varianceColor,
                  ),
                ),
              ],
            ),
            if (report.lines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: ThemePalette.border(context)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text('colName'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'pvfPlannedFact'.tr(),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'pvfVariance'.tr(),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
              for (final line in report.lines)
                _VarianceRow(line: line),
            ],
          ],
        ),
      ),
    );
  }
}

class _VarianceRow extends StatelessWidget {
  const _VarianceRow({required this.line});

  final PlanVarianceLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = line.variancePct;
    final over = (pct ?? line.varianceQty) > 0;
    final color = pct == null && line.varianceQty == 0
        ? ThemePalette.onSurfaceMuted(context)
        : (over ? AppColors.dangerRed : AppColors.profitGreen);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              line.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${_qty(line.theoreticalQty, line.unit)} → '
              '${_qty(line.actualQty, line.unit)}',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              pct != null
                  ? '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(0)}%'
                  : _qty(line.varianceQty, line.unit),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Пилюли периода: День · Неделя · Месяц (в стиле приёмов пищи на дашборде блюд).
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final track = ThemePalette.isLight(context)
        ? AppColorsLight.surfaceSecondary
        : AppColors.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: ThemePalette.border(context)),
        ),
        child: Row(
          children: [
            for (final period in _periods)
              Expanded(
                child: _PeriodTab(
                  label: _periodLabel(period),
                  isActive: period == selected,
                  onTap: () => onSelected(period),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = ThemePalette.isLight(context);
    final activeFill =
        isLight ? AppColorsLight.accentSoftStrong : ThemePalette.accent(context);
    final activeText =
        isLight ? AppColorsLight.onAccentSoftStrong : AppColors.onPrimary;
    final inactiveText = ThemePalette.onSurfaceMuted(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? activeFill : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isActive ? activeText : inactiveText,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: ThemePalette.onSurfaceMuted(context)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color ?? ThemePalette.onSurface(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Операционные KPI менеджера: эскалации шефа, условные планы, активные
/// контракты и (если не скрыто RBAC) денежное влияние отклонений.
class _ManagerKpiGrid extends StatelessWidget {
  const _ManagerKpiGrid({required this.data});

  final ManagerDashboardModel data;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _KpiTile(
        title: 'kpiOpenEscalations'.tr(),
        value: _count(data.openChefEscalations),
        color: data.openChefEscalations > 0 ? AppColors.dangerRed : null,
        icon: data.openChefEscalations > 0
            ? Icons.priority_high_rounded
            : Icons.check_circle_outline_rounded,
      ),
      _KpiTile(
        title: 'kpiConditionalPlans'.tr(),
        value: _count(data.conditionalPlans),
        color: data.conditionalPlans > 0 ? AppColors.warningAmber : null,
      ),
      _KpiTile(
        title: 'kpiActiveContracts'.tr(),
        value: _count(data.activeContracts),
      ),
      if (data.showVarianceCost)
        _KpiTile(
          title: 'kpiVarianceImpact'.tr(),
          value: _money(data.varianceCostImpact),
          color: data.varianceCostImpact > 0 ? AppColors.dangerRed : null,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        final cardWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: cardWidth, child: item),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.value,
    this.color,
    this.icon,
  });

  final String title;
  final String value;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = color ?? ThemePalette.onSurface(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: ThemePalette.onSurfaceMuted(context)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: valueColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';
import 'package:mezzome/features/dashboard/presentation/providers/expenses_notifier.dart';
import 'package:mezzome/features/dashboard/presentation/providers/expenses_state.dart';

/// Экран «Расходы» — все денежные потоки за день/неделю/месяц/год.
/// Показывает только расход (без выручки): итоги по периодам и разбивку по
/// категориям выбранного периода.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(expensesNotifierProvider);
    final notifier = ref.read(expensesNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('expensesTitle'.tr()),
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
        error: (error, _) =>
            _ExpensesError(error: error, onRetry: notifier.refresh),
        data: (state) => Column(
          children: [
            if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                color: ThemePalette.accent(context),
                onRefresh: notifier.refresh,
                child: _ExpensesContent(
                  state: state,
                  onSelectPeriod: notifier.selectPeriod,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Форматирование денег: целые тенге с разделением разрядов («1 250 000 ₸»).
String formatTenge(double value) {
  final formatted = NumberFormat.decimalPattern('ru').format(value.round());
  return '$formatted ₸';
}

class _ExpensesContent extends StatelessWidget {
  const _ExpensesContent({required this.state, required this.onSelectPeriod});

  final ExpensesState state;
  final ValueChanged<ExpensePeriod> onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    final selectedData = state.selectedData;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'expensesPeriodsTitle'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PeriodCardsGrid(state: state, onSelectPeriod: onSelectPeriod),
        const SizedBox(height: AppSpacing.lg),
        _CategoriesSection(period: state.selected, data: selectedData),
      ],
    );
  }
}

/// Сетка 2×2 карточек периодов (день/неделя/месяц/год). Тап выбирает период
/// для разбивки по категориям ниже.
class _PeriodCardsGrid extends StatelessWidget {
  const _PeriodCardsGrid({required this.state, required this.onSelectPeriod});

  final ExpensesState state;
  final ValueChanged<ExpensePeriod> onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    Widget cardFor(ExpensePeriod period) {
      final data = state.byPeriod[period];
      return Expanded(
        child: _PeriodCard(
          label: periodLabel(period),
          amount: data?.total,
          selected: state.selected == period,
          onTap: () => onSelectPeriod(period),
        ),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cardFor(ExpensePeriod.day),
              const SizedBox(width: AppSpacing.sm),
              cardFor(ExpensePeriod.week),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cardFor(ExpensePeriod.month),
              const SizedBox(width: AppSpacing.sm),
              cardFor(ExpensePeriod.year),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.label,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double? amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    final borderRadius = BorderRadius.circular(AppSpacing.radiusMd);

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.10)
          : ThemePalette.surfaceCard(context),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: selected ? accent : ThemePalette.border(context),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                amount == null ? '—' : formatTenge(amount!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Разбивка расходов по категориям выбранного периода с долями.
class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.period, required this.data});

  final ExpensePeriod period;
  final ExpensesDashboardModel? data;

  @override
  Widget build(BuildContext context) {
    final total = data?.total ?? 0;
    final entries = (data?.byCategory.entries.toList() ?? [])
      ..removeWhere((e) => e.value <= 0)
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'expensesCategoriesTitle'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              periodLabel(period),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (entries.isEmpty)
          _EmptyExpenses()
        else
          Container(
            decoration: BoxDecoration(
              color: ThemePalette.surfaceCard(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: ThemePalette.border(context)),
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _CategoryRow(
                    label: categoryLabel(entries[i].key),
                    amount: entries[i].value,
                    sharePct: total > 0 ? entries[i].value / total * 100 : 0,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.amount,
    required this.sharePct,
  });

  final String label;
  final double amount;
  final double sharePct;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatTenge(amount),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(
                '${sharePct.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (sharePct / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: ThemePalette.border(context),
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      ],
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: ThemePalette.onSurfaceMuted(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'expensesEmpty'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ThemePalette.onSurfaceMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesError extends StatelessWidget {
  const _ExpensesError({required this.error, required this.onRetry});

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
              size: 48,
              color: ThemePalette.onSurfaceMuted(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'expensesLoadError'.tr(),
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

/// Локализованная подпись периода.
String periodLabel(ExpensePeriod period) {
  return switch (period) {
    ExpensePeriod.day => 'expensePeriodDay'.tr(),
    ExpensePeriod.week => 'expensePeriodWeek'.tr(),
    ExpensePeriod.month => 'expensePeriodMonth'.tr(),
    ExpensePeriod.year => 'expensePeriodYear'.tr(),
  };
}

/// Локализованная подпись категории расхода. Если ключ неизвестен — возвращаем
/// сам ключ, чтобы не показывать путь перевода.
String categoryLabel(String key) {
  final label = 'expenseCategory.$key'.tr();
  return label == 'expenseCategory.$key' ? key : label;
}

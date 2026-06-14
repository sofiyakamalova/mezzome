import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_grid_model.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';
import 'package:mezzome/features/dishes/domain/scale_variance.dart';
import 'package:mezzome/features/dishes/domain/tech_card_history.dart';

/// Полноэкранная страница техкарты (открывается по тапу на ячейку сетки).
///
/// Данные берём из реального API: деталь техкарты (`dto.TechnicalCardResponse`),
/// блюдо меню (цена + аллергены) и история. Заглушкой остаётся только «факт по
/// весам» (CAS/LongFig) — там нужен запрос по плану/партии (см.
/// docs/backend-techcard-needs.md).
class TechCardPage extends ConsumerStatefulWidget {
  const TechCardPage({
    super.key,
    required this.item,
    required this.date,
    required this.signature,
    required this.showFinancials,
    this.onEdit,
  });

  final ProductionPlanGridCellItem item;
  final DateTime? date;
  final String signature;
  final bool showFinancials;

  /// Открыть существующий редактор техкарты (bottom-sheet). После него страница
  /// перечитывает данные.
  final Future<void> Function()? onEdit;

  static Future<void> open(
    BuildContext context, {
    required ProductionPlanGridCellItem item,
    required DateTime? date,
    required String signature,
    required bool showFinancials,
    Future<void> Function()? onEdit,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TechCardPage(
          item: item,
          date: date,
          signature: signature,
          showFinancials: showFinancials,
          onEdit: onEdit,
        ),
      ),
    );
  }

  @override
  ConsumerState<TechCardPage> createState() => _TechCardPageState();
}

class _PageData {
  const _PageData(this.card, this.dish, this.history, this.scale);
  final TechnicalCardModel? card;
  final DishModel? dish;
  final TechCardHistoryResult history;
  final ScaleVarianceResult scale;
}

class _TechCardPageState extends ConsumerState<TechCardPage> {
  late Future<_PageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PageData> _load() async {
    final repo = ref.read(menuDashboardRepositoryProvider);
    final item = widget.item;
    TechnicalCardModel? card;
    if (item.technicalCardId != null) {
      card = await repo.loadTechnicalCardFull(item.technicalCardId!);
    }
    if (card == null && item.menuItemId != null) {
      card = await repo.findTechnicalCardByMenuItem(item.menuItemId!);
    }
    card ??= await repo.findTechnicalCardByName(item.menuItemName ?? '');

    final menuItemId = item.menuItemId ?? card?.menuItemId;
    final dish = menuItemId == null
        ? null
        : await repo.loadMenuItem(menuItemId);

    var history = const TechCardHistoryResult();
    var scale = const ScaleVarianceResult();
    final cardId = card?.id ?? item.technicalCardId;
    if (cardId != null) {
      history = await repo.loadTechnicalCardHistory(cardId);
      scale = await repo.loadScaleVariance(cardId);
    }
    return _PageData(card, dish, history, scale);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: ThemePalette.surfacePanel(context),
      appBar: AppBar(
        title: Text('tcpTitle'.tr()),
        actions: [
          if (widget.onEdit != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: FilledButton.icon(
                onPressed: () async {
                  await widget.onEdit!();
                  if (mounted) await _reload();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('tcpEdit'.tr()),
              ),
            ),
        ],
      ),
      body: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final card = snap.data?.card;
          if (card == null) {
            return _ErrorState(
              name: item.menuItemName ?? '—',
              onRetry: _reload,
            );
          }
          return _TechCardBody(
            card: card,
            dish: snap.data!.dish,
            item: item,
            history: snap.data!.history,
            scale: snap.data!.scale,
            signature: widget.signature,
            showFinancials: widget.showFinancials,
            onEdit: widget.onEdit == null
                ? null
                : () async {
                    await widget.onEdit!();
                    if (mounted) await _reload();
                  },
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.name, required this.onRetry});

  final String name;
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
              Icons.receipt_long_outlined,
              size: 48,
              color: ThemePalette.onSurfaceMuted(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'tcpLoadError'.tr(namedArgs: {'name': name}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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

/// Стоимость строки ингредиента (₸): серверная `total_cost`, иначе считаем
/// `netto/1000 × cost_per_unit` (для ₸/кг). Единый источник для «Суммы» и итога.
double _ingredientLineCost(TechnicalCardIngredientModel i) {
  if (i.totalCost > 0) return i.totalCost;
  return (i.netto / 1000) * i.costPerUnit;
}

/// Производные числа техкарты (себестоимость, баланс массы, фудкост/маржа),
/// посчитанные клиентом из состава и цены блюда.
class _Derived {
  _Derived(TechnicalCardModel card, DishModel? dish)
    : basePortions = card.basePortions <= 0 ? 1 : card.basePortions,
      outputPerPortion = card.outputPerPortion,
      outputUnit = card.outputUnit,
      costPerPortion = _resolveCostPerPortion(card, dish) {
    nettoPerPortion = card.ingredients.fold(0, (s, i) => s + i.netto);
    bruttoPerPortion = card.ingredients.fold(0, (s, i) => s + i.brutto);
  }

  final double basePortions;
  final double outputPerPortion;
  final String outputUnit;

  /// Себестоимость **порции** в ₸ (Σ нетто×цена). НЕ `food_cost` (тот — процент).
  final double costPerPortion;
  double nettoPerPortion = 0;
  double bruttoPerPortion = 0;

  double get nettoTotal => nettoPerPortion * basePortions;
  double get bruttoTotal => bruttoPerPortion * basePortions;
  double get yieldTotal => outputPerPortion * basePortions;
  double get lossTotal => (bruttoTotal - nettoTotal).clamp(0, double.infinity);
  double get massDiff => nettoTotal - yieldTotal;
  double get massDiffPct => yieldTotal > 0 ? massDiff / yieldTotal * 100 : 0;
  bool get massInNorm => massDiffPct.abs() <= 5;

  /// Себестоимость порции: приоритет — серверный `cost_per_portion` блюда,
  /// иначе Σ построчных стоимостей (таблица «на 1 порцию»), иначе
  /// `total_ingredient_cost / base_portions`. `food_cost` (процент) НЕ
  /// используем как ₸ — это и был баг «0.08 ₸».
  static double _resolveCostPerPortion(
    TechnicalCardModel card,
    DishModel? dish,
  ) {
    final dishCost = dish?.costPerPortion;
    if (dishCost != null && dishCost > 0) return dishCost;
    if (card.ingredients.isNotEmpty) {
      final sum = card.ingredients.fold<double>(
        0,
        (s, i) => s + _ingredientLineCost(i),
      );
      if (sum > 0) return sum;
    }
    final base = card.basePortions <= 0 ? 1 : card.basePortions;
    if (card.totalIngredientCost > 0) return card.totalIngredientCost / base;
    return 0;
  }
}

class _TechCardBody extends StatelessWidget {
  const _TechCardBody({
    required this.card,
    required this.dish,
    required this.item,
    required this.history,
    required this.scale,
    required this.signature,
    required this.showFinancials,
    this.onEdit,
  });

  final TechnicalCardModel card;
  final DishModel? dish;
  final ProductionPlanGridCellItem item;
  final TechCardHistoryResult history;
  final ScaleVarianceResult scale;
  final String signature;
  final bool showFinancials;
  final Future<void> Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    final d = _Derived(card, dish);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final allergens = dish?.allergens ?? const <String>[];

    final yieldCard = _YieldCard(card: card, derived: d, item: item);
    final scaleCard = _ScaleFactCard(scale: scale);
    final reasonCard =
        (card.approvalReason != null && card.approvalReason!.trim().isNotEmpty)
        ? _ReasonCard(reason: card.approvalReason!)
        : null;

    // Правая колонка нижнего ряда: факт по весам + причина правки (как в макете).
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scaleCard,
        if (reasonCard != null) ...[
          const SizedBox(height: AppSpacing.sm),
          reasonCard,
        ],
      ],
    );

    // Центрируем и ограничиваем ширину на десктопе (плотный канвас как в макете).
    const maxCanvas = 1180.0;
    final horizontal = ((width - maxCanvas) / 2).clamp(
      AppSpacing.sm,
      double.infinity,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal.toDouble(),
              vertical: AppSpacing.sm,
            ),
            children: [
              _HeaderCard(
                card: card,
                allergens: allergens,
                nutrition: dish?.nutritionInfo,
              ),
              const SizedBox(height: AppSpacing.sm),
              _StepperCard(card: card, wide: wide),
              const SizedBox(height: AppSpacing.sm),
              if (showFinancials) ...[
                _KpiSection(derived: d, wide: wide),
                const SizedBox(height: AppSpacing.sm),
              ],
              _MassBalanceCard(derived: d),
              const SizedBox(height: AppSpacing.sm),
              _IngredientsCard(
                card: card,
                showFinancials: showFinancials,
                onEdit: onEdit,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: yieldCard),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: rightColumn),
                    ],
                  ),
                )
              else ...[
                yieldCard,
                const SizedBox(height: AppSpacing.sm),
                rightColumn,
              ],
              if (card.steps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _StepsCard(steps: card.steps),
              ],
              const SizedBox(height: AppSpacing.sm),
              _HistoryCard(history: history),
            ],
          ),
        ),
        _BottomBar(signature: signature),
      ],
    );
  }
}

/// Карточка-секция с заголовком и иконкой.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: ThemePalette.onSurfaceMuted(context),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ThemePalette.onSurfaceMuted(context),
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Чип «ожидает данных бэкенда» — помечает блоки без серверных полей.
class _PendingChip extends StatelessWidget {
  const _PendingChip({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: compact ? 11 : 13,
            color: AppColors.warningAmber,
          ),
          const SizedBox(width: 4),
          Text(
            'tcpPendingData'.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warningAmber,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Маленький бейдж-пилюля с цветом.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.card,
    required this.allergens,
    this.nutrition,
  });

  final TechnicalCardModel card;
  final List<String> allergens;
  final Map<String, dynamic>? nutrition;

  @override
  Widget build(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return _Section(
      title: 'tcpTitle'.tr(),
      icon: Icons.receipt_long_outlined,
      trailing: card.categoryName == null
          ? null
          : _Pill(
              label: card.categoryName!,
              color: ThemePalette.accent(context),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  card.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (card.isLatest)
                _Pill(
                  label: 'tcpActiveBadge'.tr(),
                  color: AppColors.profitGreen,
                  icon: Icons.check_circle_outline,
                ),
              if (card.version != null) ...[
                const SizedBox(width: 6),
                Text(
                  'tcpVersion'.tr(namedArgs: {'version': '${card.version}'}),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // created_by приходит как id — имя/роль бэкенд не разворачивает.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'tcpAuthor'.tr(
                      namedArgs: {
                        'author': card.createdBy == null
                            ? '—'
                            : 'ID ${card.createdBy}',
                      },
                    ),
                    style: bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
              if (card.createdAt != null)
                Text(
                  'tcpCreated'.tr(
                    namedArgs: {
                      'date': DateFormatUtil.formatDateTimeShort(
                        card.createdAt!,
                      ),
                    },
                  ),
                  style: bodySmall?.copyWith(color: muted),
                ),
              if (card.updatedAt != null)
                Text(
                  'tcpUpdated'.tr(
                    namedArgs: {
                      'date': DateFormatUtil.formatDateTimeShort(
                        card.updatedAt!,
                      ),
                    },
                  ),
                  style: bodySmall?.copyWith(color: muted),
                ),
            ],
          ),
          if (allergens.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '${'tcpColAllergens'.tr()}:',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in allergens)
                        _Pill(label: a, color: AppColors.warningAmber),
                    ],
                  ),
                ),
              ],
            ),
          ],
          _NutritionRow(nutrition: nutrition),
        ],
      ),
    );
  }
}

/// КБЖУ (P2.11) — мягкий разбор свободного `nutrition_info`. Если данных нет —
/// ничего не рисуем (без DEV-плейсхолдеров).
class _NutritionRow extends StatelessWidget {
  const _NutritionRow({required this.nutrition});

  final Map<String, dynamic>? nutrition;

  double? _pick(List<String> keys) {
    final raw = nutrition;
    if (raw == null) return null;
    for (final e in raw.entries) {
      final k = e.key.toLowerCase();
      if (!keys.any(k.contains)) continue;
      final v = e.value;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      if (v is Map && v['value'] is num) return (v['value'] as num).toDouble();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kcal = _pick(['calor', 'kcal', 'ккал', 'энерг', 'energy']);
    final prot = _pick(['protein', 'белок', 'белк', 'prot']);
    final fat = _pick(['fat', 'жир']);
    final carb = _pick(['carb', 'углевод', 'углев']);
    final parts = <String>[
      if (kcal != null) '${'tcpKcal'.tr()} ${kcal.toStringAsFixed(0)}',
      if (prot != null) '${'tcpProtein'.tr()} ${prot.toStringAsFixed(1)}',
      if (fat != null) '${'tcpFat'.tr()} ${fat.toStringAsFixed(1)}',
      if (carb != null) '${'tcpCarbs'.tr()} ${carb.toStringAsFixed(1)}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    final muted = ThemePalette.onSurfaceMuted(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_outlined, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ThemePalette.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Этапы воркфлоу. Текущий шаг — эвристика по статусу (структурного массива
/// этапов бэкенд пока не отдаёт).
class _StepperCard extends StatelessWidget {
  const _StepperCard({required this.card, required this.wide});

  final TechnicalCardModel card;
  final bool wide;

  int get _activeIndex {
    final s = (card.status ?? '').toLowerCase();
    final a = (card.approvalStatus ?? '').toLowerCase();
    if (a == 'approved' || s == 'approved' || s == 'active') return 3;
    if (a == 'pending' || s.contains('pending')) return 2;
    if (s == 'draft') return 1;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      'tcpStepChef'.tr(),
      'tcpStepManager'.tr(),
      'tcpStepShop'.tr(),
      'tcpStepDone'.tr(),
    ];
    // Дата на этапе (имена авторов бэкенд пока не разворачивает — только id).
    final dates = <DateTime?>[
      card.createdAt,
      card.updatedAt,
      card.submittedAt,
      card.approvedAt,
    ];
    final active = _activeIndex;

    _StepState stateAt(int i) => i < active
        ? _StepState.done
        : (i == active ? _StepState.active : _StepState.pending);

    String? subAt(int i) => dates[i] == null
        ? null
        : DateFormatUtil.formatDateTimeShort(dates[i]!);

    Widget connector(int i) => Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: i < active ? AppColors.profitGreen : ThemePalette.border(context),
    );

    // На широком экране сегменты растягиваются на всю ширину (как в макете),
    // на узком — горизонтальный скролл.
    final row = Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepDot(label: steps[i], state: stateAt(i), sub: subAt(i)),
          if (i < steps.length - 1)
            wide
                ? Expanded(child: connector(i))
                : SizedBox(width: 28, child: connector(i)),
        ],
      ],
    );

    return _Section(
      title: 'tcpWorkflow'.tr(),
      icon: Icons.route_outlined,
      child: wide
          ? row
          : SingleChildScrollView(scrollDirection: Axis.horizontal, child: row),
    );
  }
}

enum _StepState { done, active, pending }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.state, this.sub});

  final String label;
  final _StepState state;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (state) {
      _StepState.done => (AppColors.profitGreen, Icons.check_rounded),
      _StepState.active => (AppColors.warningAmber, Icons.edit_rounded),
      _StepState.pending => (
        ThemePalette.onSurfaceMuted(context),
        Icons.circle_outlined,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: state == _StepState.pending
                    ? ThemePalette.onSurfaceMuted(context)
                    : ThemePalette.onSurface(context),
                fontWeight: state == _StepState.active
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.derived, required this.wide});

  final _Derived derived;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final d = derived;
    // Показываем только себестоимость порции и выход — без цены продажи,
    // фудкоста и маржи (по требованию заказчика: «только себестоимость»).
    final cards = <Widget>[
      _KpiCard(
        label: 'tcpKpiCost'.tr(),
        value: '${d.costPerPortion.toStringAsFixed(2)} ₸',
        icon: Icons.payments_outlined,
      ),
      _KpiCard(
        label: 'tcpKpiYield'.tr(),
        value: '${d.outputPerPortion.toStringAsFixed(0)} ${d.outputUnit}',
        sub: 'tcpKpiPortions'.tr(
          namedArgs: {'count': '${d.basePortions.round()}'},
        ),
        icon: Icons.scale_outlined,
      ),
    ];

    // Десктоп — равные карточки в один ряд (как в макете); мобильный — сетка.
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [for (final c in cards) SizedBox(width: 168, child: c)],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    this.sub,
    this.icon,
  });

  final String label;
  final String value;
  final String? sub;
  final IconData? icon;

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
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: ThemePalette.onSurfaceMuted(context),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ThemePalette.onSurfaceMuted(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
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

class _MassBalanceCard extends StatelessWidget {
  const _MassBalanceCard({required this.derived});

  final _Derived derived;

  @override
  Widget build(BuildContext context) {
    final d = derived;
    final inNorm = d.massInNorm;
    final color = inNorm ? AppColors.profitGreen : AppColors.dangerRed;
    return _Section(
      title: 'tcpMassBalance'.tr(),
      icon: Icons.balance_outlined,
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Metric(
                label: 'tcpMassNetto'.tr(),
                value: '${d.nettoTotal.toStringAsFixed(0)} г',
                emphasize: true,
              ),
              _Metric(
                label: 'tcpMassYield'.tr(),
                value: '${d.yieldTotal.toStringAsFixed(0)} г',
              ),
              _Metric(
                label: 'tcpMassLoss'.tr(),
                value: '${d.lossTotal.toStringAsFixed(0)} г',
              ),
              _Metric(
                label: 'tcpMassBrutto'.tr(),
                value: '${d.bruttoTotal.toStringAsFixed(0)} г',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${'tcpMassDiff'.tr()}: ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                ),
              ),
              Text(
                '${d.massDiff >= 0 ? '+' : ''}${d.massDiff.toStringAsFixed(0)} г '
                '(${d.massDiffPct >= 0 ? '+' : ''}${d.massDiffPct.toStringAsFixed(2)}%)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _Pill(
                label: (inNorm ? 'tcpInNorm' : 'tcpOutOfNorm').tr(),
                color: color,
                icon: inNorm ? Icons.check_circle_outline : Icons.error_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ThemePalette.onSurfaceMuted(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: emphasize
                ? ThemePalette.accent(context)
                : ThemePalette.onSurface(context),
          ),
        ),
      ],
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({
    required this.card,
    required this.showFinancials,
    this.onEdit,
  });

  final TechnicalCardModel card;
  final bool showFinancials;
  final Future<void> Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final headerStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w700);
    // Итого = Σ построчных стоимостей (та же логика, что у себестоимости порции).
    final total =
        card.ingredients.fold<double>(0, (s, i) => s + _ingredientLineCost(i));

    return _Section(
      title: 'tcpIngredients'.tr(),
      icon: Icons.format_list_bulleted,
      trailing: Text(
        'tcpPerPortion'.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onEdit != null) ...[
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('addIngredient'.tr()),
                ),
                const SizedBox(width: AppSpacing.xs),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text('tcpImport'.tr()),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width - AppSpacing.sm * 4,
              ),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 52,
                columnSpacing: AppSpacing.md,
                horizontalMargin: 0,
                columns: [
                  DataColumn(label: Text('colName'.tr(), style: headerStyle)),
                  DataColumn(
                    label: Text('tcpColUnit'.tr(), style: headerStyle),
                  ),
                  DataColumn(
                    label: Text('tcpColCleaning'.tr(), style: headerStyle),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text('colBrutto'.tr(), style: headerStyle),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text('colNetto'.tr(), style: headerStyle),
                    numeric: true,
                  ),
                  if (showFinancials) ...[
                    DataColumn(
                      label: Text('colPriceKg'.tr(), style: headerStyle),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text('colSum'.tr(), style: headerStyle),
                      numeric: true,
                    ),
                  ],
                  if (onEdit != null)
                    DataColumn(
                      label: Text('tcpColActions'.tr(), style: headerStyle),
                    ),
                ],
                rows: [
                  for (final ing in card.ingredients)
                    _ingredientRow(context, ing),
                ],
              ),
            ),
          ),
          if (showFinancials) ...[
            const Divider(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${'tcpTotal'.tr()}: ',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
                Text(
                  '${total.toStringAsFixed(2)} ₸',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ThemePalette.accent(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  DataRow _ingredientRow(
    BuildContext context,
    TechnicalCardIngredientModel ing,
  ) {
    final cleaning = ing.brutto > 0 ? (ing.netto / ing.brutto) : null;
    final bodyStyle = Theme.of(context).textTheme.bodySmall;
    final muted = ThemePalette.onSurfaceMuted(context);
    return DataRow(
      cells: [
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ing.ingredientName ?? '—', style: bodyStyle),
              if (ing.cutType != null && ing.cutType!.isNotEmpty)
                Text(
                  ing.cutType!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: muted, fontSize: 10),
                ),
            ],
          ),
        ),
        DataCell(Text(ing.unit ?? 'г', style: bodyStyle)),
        DataCell(Text(cleaning?.toStringAsFixed(2) ?? '—', style: bodyStyle)),
        DataCell(Text(ing.brutto.toStringAsFixed(0), style: bodyStyle)),
        DataCell(Text(ing.netto.toStringAsFixed(0), style: bodyStyle)),
        if (showFinancials) ...[
          DataCell(Text(ing.costPerUnit.toStringAsFixed(0), style: bodyStyle)),
          DataCell(
            Text(_ingredientLineCost(ing).toStringAsFixed(2), style: bodyStyle),
          ),
        ],
        if (onEdit != null)
          DataCell(
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              color: muted,
              onPressed: onEdit,
            ),
          ),
      ],
    );
  }
}

class _YieldCard extends StatelessWidget {
  const _YieldCard({
    required this.card,
    required this.derived,
    required this.item,
  });

  final TechnicalCardModel card;
  final _Derived derived;
  final ProductionPlanGridCellItem item;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'tcpYieldSection'.tr(),
      icon: Icons.restaurant_outlined,
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          _Metric(
            label: 'tcpYieldPerDay'.tr(),
            value: '${item.plannedPortions}',
          ),
          _Metric(
            label: 'tcpKpiYield'.tr(),
            value:
                '${derived.outputPerPortion.toStringAsFixed(0)} ${derived.outputUnit}',
          ),
          _Metric(
            label: 'basePortionsLabel'.tr(),
            value: '${derived.basePortions.round()}',
          ),
        ],
      ),
    );
  }
}

/// Факт по весам (CAS / LongFig) — реальные «заявлено vs факт» из
/// `/variance/technical-cards/{id}/breakdown`. Если данных нет — заглушка.
class _ScaleFactCard extends StatelessWidget {
  const _ScaleFactCard({required this.scale});

  final ScaleVarianceResult scale;

  @override
  Widget build(BuildContext context) {
    if (!scale.hasData) {
      return _Section(
        title: 'tcpScaleFact'.tr(),
        icon: Icons.monitor_weight_outlined,
        trailing: const _PendingChip(compact: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: 0.5,
              child: Row(
                children: [
                  _Metric(label: 'tcpDeclared'.tr(), value: '— кг'),
                  const SizedBox(width: AppSpacing.lg),
                  _Metric(label: 'tcpActual'.tr(), value: '— кг'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'tcpScaleHint'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
              ),
            ),
          ],
        ),
      );
    }

    final unit = scale.unit ?? '';
    final declared = scale.declaredTotal;
    final actual = scale.actualTotal;
    final dev = actual - declared;
    final devPct = declared > 0 ? dev / declared * 100 : 0;
    final ok = devPct.abs() <= 5;
    final color = ok ? AppColors.profitGreen : AppColors.dangerRed;
    final muted = ThemePalette.onSurfaceMuted(context);

    return _Section(
      title: 'tcpScaleFact'.tr(),
      icon: Icons.monitor_weight_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Metric(
                label: 'tcpDeclared'.tr(),
                value: '${declared.toStringAsFixed(1)} $unit',
              ),
              const SizedBox(width: AppSpacing.lg),
              _Metric(
                label: 'tcpActual'.tr(),
                value: '${actual.toStringAsFixed(1)} $unit',
              ),
              const Spacer(),
              _Pill(
                label:
                    '${dev >= 0 ? '+' : ''}${dev.toStringAsFixed(1)} $unit '
                    '(${devPct >= 0 ? '+' : ''}${devPct.toStringAsFixed(1)}%)',
                color: color,
              ),
            ],
          ),
          const Divider(height: AppSpacing.md),
          for (final l in scale.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${(l.theoreticalQty ?? 0).toStringAsFixed(1)} → '
                    '${(l.actualQty ?? 0).toStringAsFixed(1)} ${l.unit ?? unit}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
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

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'tcpReason'.tr(),
      icon: Icons.comment_outlined,
      child: Text(reason, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});

  final List<TechnicalCardStepModel> steps;

  @override
  Widget build(BuildContext context) {
    final sorted = [...steps]
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    final accent = ThemePalette.accent(context);
    final muted = ThemePalette.onSurfaceMuted(context);
    return _Section(
      title: 'tcpSteps'.tr(),
      icon: Icons.list_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sorted.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == sorted.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sorted[i].name != null &&
                            sorted[i].name!.isNotEmpty)
                          Text(
                            sorted[i].name!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        if (sorted[i].description != null &&
                            sorted[i].description!.isNotEmpty)
                          Text(
                            sorted[i].description!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (sorted[i].durationMinutes != null ||
                            sorted[i].temperatureC != null ||
                            (sorted[i].kitchenSection?.isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              [
                                if (sorted[i].kitchenSection?.isNotEmpty ??
                                    false)
                                  sorted[i].kitchenSection!,
                                if (sorted[i].durationMinutes != null)
                                  '${sorted[i].durationMinutes} мин',
                                if (sorted[i].temperatureC != null)
                                  '${sorted[i].temperatureC!.toStringAsFixed(0)} °C',
                              ].join(' · '),
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: muted),
                            ),
                          ),
                      ],
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final TechCardHistoryResult history;

  @override
  Widget build(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    Widget body;
    if (history.forbidden) {
      body = Text(
        'techCardHistoryForbidden'.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
      );
    } else if (history.entries.isEmpty) {
      body = Text(
        'techCardHistoryEmpty'.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in history.entries.take(6))
            _HistoryEntryTile(entry: entry),
        ],
      );
    }
    return _Section(title: 'tcpHistory'.tr(), icon: Icons.history, child: body);
  }
}

/// Человекочитаемый лейбл поля из истории (raw-ключи → понятный текст).
String _historyFieldLabel(String field) {
  switch (field) {
    case 'name':
      return 'dishNameLabel'.tr();
    case 'base_portions':
      return 'basePortionsLabel'.tr();
    case 'output_per_portion':
      return 'yieldGramsLabel'.tr();
    case 'loss_pct':
      return 'lossPctLabel'.tr();
    case 'description':
      return 'techNotesLabel'.tr();
    case 'ingredients':
      return 'tcpIngredients'.tr();
    case 'halal_required':
      return 'halalRequiredLabel'.tr();
  }
  // Прочее: snake_case → «Snake case».
  final spaced = field.replaceAll('_', ' ').trim();
  if (spaced.isEmpty) return field;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({required this.entry});

  final TechCardHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final accent = ThemePalette.accent(context);
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final labelSmall = Theme.of(context).textTheme.labelSmall;

    final author = entry.authorLabel ?? '—';
    final hasVersion = entry.fromVersion != null && entry.toVersion != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: ThemePalette.surfacePanel(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: ThemePalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // КТО + КОГДА.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, size: 15, color: accent),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // 'tcpChangedBy'.tr(namedArgs: {'author': author}) ,
                      '${'tcpChangedBy'.tr()} $author',

                      style: bodySmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (entry.timestamp != null)
                      Text(
                        DateFormatUtil.formatDateTimeShort(entry.timestamp!),
                        style: labelSmall?.copyWith(color: muted),
                      ),
                  ],
                ),
              ),
              // Версия + уровень изменения.
              Wrap(
                spacing: 4,
                children: [
                  if (hasVersion)
                    _Pill(
                      label: 'v${entry.fromVersion} → v${entry.toVersion}',
                      color: accent,
                    ),
                  if (entry.changeLevel != null)
                    _Pill(
                      label: entry.changeLevel!,
                      color: AppColors.warningAmber,
                    ),
                ],
              ),
            ],
          ),
          // ЧТО + КАК.
          if (entry.changes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final change in entry.changes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        _historyFieldLabel(change.field),
                        style: bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _ValueChip(
                            text: change.oldValue.isEmpty
                                ? '—'
                                : change.oldValue,
                            color: AppColors.dangerRed,
                            strike: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 13,
                              color: muted,
                            ),
                          ),
                          _ValueChip(
                            text: change.newValue.isEmpty
                                ? '—'
                                : change.newValue,
                            color: AppColors.profitGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ] else if (entry.changedFields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'techCardHistoryFields'.tr(
                  namedArgs: {
                    'fields': entry.changedFields
                        .map(_historyFieldLabel)
                        .join(', '),
                  },
                ),
                style: bodySmall?.copyWith(color: muted),
              ),
            )
          else if (entry.action != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'techCardHistoryAction'.tr(
                  namedArgs: {'action': entry.action!},
                ),
                style: bodySmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Значение в истории (было/стало) как маленький цветной чип.
class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.text,
    required this.color,
    this.strike = false,
  });

  final String text;
  final Color color;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          decoration: strike ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.signature});

  final String signature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        border: Border(top: BorderSide(color: ThemePalette.border(context))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(
              Icons.draw_outlined,
              size: 14,
              color: ThemePalette.onSurfaceMuted(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'tcpSignature'.tr(namedArgs: {'signature': signature}),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

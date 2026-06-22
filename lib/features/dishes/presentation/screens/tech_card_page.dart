import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/presentation/blocs/tech_card_cubit.dart';
// Дизайн карточки (скопирован в widgets/recipe_card).
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/app_theme.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/common_widgets.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/dish_header.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/gallery_and_nutrition.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/header_widgets.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/history_timeline.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/instruction_lists.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/recipe_models.dart';
import 'package:mezzome/features/dishes/presentation/widgets/recipe_card/recipe_table.dart';

/// Полноэкранная страница техкарты (дизайн из прототипа example/, реальные
/// данные из [TechCardCubit]). Открывается по тапу на ячейку сетки.
class TechCardPage extends StatefulWidget {
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

  /// Открыть редактор техкарты (bottom-sheet). После него страница перечитывает данные.
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
  State<TechCardPage> createState() => _TechCardPageState();
}

class _TechCardPageState extends State<TechCardPage> {
  late final TechCardCubit _cubit = sl<TechCardCubit>()..load(widget.item);

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _onEdit() async {
    final edit = widget.onEdit;
    if (edit == null) return;
    await edit();
    if (mounted) _cubit.load(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<TechCardCubit, TechCardState>(
          bloc: _cubit,
          builder: (context, state) {
            if (state.status == TechCardStatus.loading) {
              return Column(
                children: [
                  _BackBar(onBack: () => Navigator.of(context).maybePop()),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            final data = state.data;
            if (data == null) {
              return Column(
                children: [
                  _BackBar(onBack: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: _ErrorState(
                      name: widget.item.menuItemName ?? '—',
                      onRetry: () => _cubit.load(widget.item),
                    ),
                  ),
                ],
              );
            }
            return _RecipeView(
              recipe: _mapRecipe(data, showMoney: widget.showFinancials),
              nutrition: _mapNutrition(data.card.compliance),
              compliance: data.card.compliance,
              status: _statusInfo(data.card),
              onBack: () => Navigator.of(context).maybePop(),
              onEdit: widget.onEdit == null ? null : _onEdit,
            );
          },
        ),
      ),
    );
  }
}

/// Минимальная панель с кнопкой «назад» (для состояний загрузки/ошибки).
class _BackBar extends StatelessWidget {
  const _BackBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.textBody),
        ),
      ),
    );
  }
}

/// Подпись + цвет статуса техкарты.
typedef _StatusInfo = ({String label, Color color});

_StatusInfo _statusInfo(TechnicalCardModel card) {
  final s = (card.status ?? '').toLowerCase();
  final a = (card.approvalStatus ?? '').toLowerCase();
  if (s == 'rejected' || a == 'rejected') {
    return (label: 'Отклонена', color: const Color(0xFFE5484D));
  }
  if (s == 'pending' || s == 'pending_approval' || a == 'pending') {
    return (label: 'На согласовании', color: const Color(0xFFE2A53B));
  }
  if (s == 'draft') {
    return (label: 'Черновик', color: AppColors.textMuted);
  }
  if (card.isLatest || s == 'approved' || a == 'approved') {
    return (label: 'Активна', color: const Color(0xFF1D9E75));
  }
  return (label: card.status ?? '—', color: AppColors.textMuted);
}

// ── Верстка (из example/, без секции «Качество», с нашим фото/КБЖУ) ──────────

class _RecipeView extends StatelessWidget {
  const _RecipeView({
    required this.recipe,
    required this.nutrition,
    required this.compliance,
    required this.status,
    required this.onBack,
    this.onEdit,
  });

  final RecipeCard recipe;
  final Nutrition? nutrition;
  final TechnicalCardCompliance? compliance;
  final _StatusInfo status;
  final VoidCallback onBack;
  final VoidCallback? onEdit;

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
            child: LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= _wideBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(),
                    const SizedBox(height: 18),
                    _statusRow(),
                    const SizedBox(height: 24),
                    isWide ? _wideBody() : _narrowBody(),
                    const SizedBox(height: 40),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 28),
                    const SectionTitle(title: 'История изменений'),
                    const SizedBox(height: 20),
                    HistoryTimeline(entries: recipe.history),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Верхняя панель в стиле example: назад + лого, справа — кнопка правки.
  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.textBody),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            const MezzomeLogo(),
          ],
        ),
        if (onEdit != null) EditButton(onTap: onEdit),
      ],
    );
  }

  Widget _statusRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Breadcrumbs(items: ['Меню', 'Технологическая карта']),
        const SizedBox(height: 16),
        StatusBadge(label: status.label, color: status.color),
      ],
    );
  }

  Widget _statCards() {
    return Row(
      children: [
        Expanded(
          child: StatCard(label: 'Выход одной порции', value: recipe.portionOutput),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: StatCard(label: 'Количество порций', value: recipe.portionsCount),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: StatCard(
              label: 'Себестоимость порции', value: recipe.costPerPortion),
        ),
      ],
    );
  }

  Widget _technology() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderBanner(title: 'Технология приготовления'),
        const SizedBox(height: 18),
        TechnologyList(steps: recipe.technology),
      ],
    );
  }

  /// Правая колонка: фото, КБЖУ, аллергены/халяль.
  List<Widget> _sideBlocks() {
    return [
      _DishPhoto(url: recipe.images.isNotEmpty ? recipe.images.first : null),
      if (nutrition != null) ...[
        const SizedBox(height: 22),
        const SectionTitle(title: 'Пищевая ценность 1 порции'),
        const SizedBox(height: 12),
        NutritionPanel(nutrition: nutrition!),
      ],
      if (_CompliancePanel.hasData(compliance)) ...[
        const SizedBox(height: 22),
        const SectionTitle(title: 'Аллергены и халяль'),
        const SizedBox(height: 12),
        _CompliancePanel(compliance: compliance!),
      ],
    ];
  }

  Widget _wideBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DishHeader(recipe: recipe),
                  const SizedBox(height: 28),
                  _statCards(),
                  const SizedBox(height: 28),
                  const SectionTitle(title: 'Рецептура'),
                  const SizedBox(height: 14),
                  RecipeTable(items: recipe.ingredients),
                ],
              ),
            ),
            const SizedBox(width: 32),
            SizedBox(
              width: 340,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _sideBlocks(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        _technology(),
      ],
    );
  }

  Widget _narrowBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DishHeader(recipe: recipe),
        const SizedBox(height: 24),
        _statCards(),
        const SizedBox(height: 24),
        ..._sideBlocks(),
        const SizedBox(height: 28),
        const SectionTitle(title: 'Рецептура'),
        const SizedBox(height: 14),
        RecipeTable(items: recipe.ingredients),
        const SizedBox(height: 32),
        _technology(),
      ],
    );
  }
}

/// Одно фото блюда или плейсхолдер (галереи из нескольких бэк не отдаёт).
class _DishPhoto extends StatelessWidget {
  const _DishPhoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.image),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: (url == null || url!.isEmpty)
            ? Container(
                color: AppColors.placeholder,
                child: const Icon(Icons.restaurant_menu,
                    size: 40, color: AppColors.textMuted),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.placeholder,
                  child: const Icon(Icons.restaurant_menu,
                      size: 40, color: AppColors.textMuted),
                ),
              ),
      ),
    );
  }
}

/// Панель аллергенов + халяль (из compliance_summary).
class _CompliancePanel extends StatelessWidget {
  const _CompliancePanel({required this.compliance});

  final TechnicalCardCompliance compliance;

  static bool hasData(TechnicalCardCompliance? c) =>
      c != null && (c.allergens.isNotEmpty || c.halalRequired);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compliance.halalRequired) ...[
            Row(
              children: [
                Icon(
                  compliance.halalCompliant
                      ? Icons.verified
                      : Icons.error_outline,
                  size: 18,
                  color: compliance.halalCompliant
                      ? const Color(0xFF1D9E75)
                      : const Color(0xFFE5484D),
                ),
                const SizedBox(width: 8),
                Text(
                  compliance.halalCompliant
                      ? 'Халяль: соответствует'
                      : 'Халяль: не соответствует',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            if (compliance.allergens.isNotEmpty) const SizedBox(height: 12),
          ],
          if (compliance.allergens.isNotEmpty) ...[
            const Text('Аллергены', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in compliance.allergens)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF3C7C7)),
                    ),
                    child: Text(
                      _allergenLabel(a),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFC23B3B),
                        fontWeight: FontWeight.w600,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.name, required this.onRetry});

  final String name;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              '${'tcpNotFound'.tr()}\n$name',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textBody),
            ),
            const SizedBox(height: 16),
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

// ── Маппинг реальных данных → модель дизайна (RecipeCard) ────────────────────

RecipeCard _mapRecipe(TechCardData data, {required bool showMoney}) {
  final card = data.card;

  String money(double v) => showMoney ? _money(v) : '—';

  final costPerPortion =
      card.basePortions > 0 ? card.totalIngredientCost / card.basePortions : 0.0;

  final ingredients = <Ingredient>[
    for (var i = 0; i < card.ingredients.length; i++)
      () {
        final ing = card.ingredients[i];
        return Ingredient(
          number: i + 1,
          product: ing.ingredientName ?? '—',
          grossG: ing.brutto.round(),
          netG: ing.netto.round(),
          lossPercent:
              ing.cleaningPct != null ? '${_trim(ing.cleaningPct!)}%' : '—',
          pricePerKg: money(ing.costPerUnit),
          sum: money(ing.totalCost),
        );
      }(),
  ];

  final steps = <TechStep>[
    for (final s in card.steps)
      TechStep(
        title: (s.name != null && s.name!.isNotEmpty) ? s.name! : 'Шаг',
        description: s.description ?? '',
      ),
  ];

  final history = <HistoryEntry>[
    for (final e in data.history.entries)
      HistoryEntry(
        date: _fmtDate(e.timestamp),
        role: e.changeLevel ?? '',
        author: e.authorName ?? '—',
        action: e.action ?? '',
        detail: e.changedFields.isNotEmpty ? e.changedFields.join(', ') : null,
        roleColor: _historyColor(e.action),
      ),
  ];

  return RecipeCard(
    title: card.name,
    categories: [if (card.categoryName != null) card.categoryName!],
    createdInfo: card.createdAt != null
        ? 'Создано ${_fmtDate(card.createdAt)}'
        : '',
    updatedInfo: [
      if (card.updatedAt != null) 'Обновлено ${_fmtDate(card.updatedAt)}',
      if (card.version != null) 'в.${card.version}',
    ].join(' · '),
    portionOutput: '${_trim(card.outputPerPortion)} ${card.outputUnit}',
    portionsCount: _trim(card.basePortions),
    costPerPortion: money(costPerPortion),
    ingredients: ingredients,
    images: card.photoUrls.where((u) => u.isNotEmpty).toList(),
    // Реальное КБЖУ передаётся отдельным полем в _RecipeView; здесь — заглушка,
    // т.к. RecipeCard.nutrition не nullable (модель прототипа).
    nutrition: const Nutrition(protein: '—', fat: '—', carbs: '—', calories: '—'),
    technology: steps,
    quality: const [], // секция скрыта (бэк не отдаёт)
    history: history,
  );
}

/// КБЖУ на порцию из compliance_summary.nutrition_per_portion. null — если
/// данных нет (секция скрывается).
Nutrition? _mapNutrition(TechnicalCardCompliance? c) {
  final per = c?.nutritionPerPortion;
  if (per == null || per.isEmpty) return null;
  final p = _num(per['protein_g']);
  final f = _num(per['fat_g']);
  final cb = _num(per['carbs_g']);
  final kcal = _num(per['calories']);
  if (p == null && f == null && cb == null && kcal == null) return null;
  String g(double? v) => v == null ? '—' : '${_trim(v)} г';
  return Nutrition(
    protein: g(p),
    fat: g(f),
    carbs: g(cb),
    calories: kcal == null ? '—' : '${kcal.round()}',
  );
}

double? _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _trim(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

String _money(double v) {
  final digits = v.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${v < 0 ? '-' : ''}$buf ₸';
}

String _fmtDate(DateTime? dt) {
  if (dt == null) return '';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d.$m.${dt.year}';
}

Color _historyColor(String? action) {
  switch ((action ?? '').toLowerCase()) {
    case 'approved':
    case 'approve':
      return const Color(0xFF1D9E75);
    case 'rejected':
    case 'reject':
      return const Color(0xFFE5484D);
    default:
      return AppColors.primary;
  }
}

/// Подпись аллергена по коду (`milk`, `gluten`…), с фолбэком на сам код.
String _allergenLabel(String code) {
  const map = {
    'milk': 'Молоко',
    'gluten': 'Глютен',
    'eggs': 'Яйца',
    'egg': 'Яйца',
    'nuts': 'Орехи',
    'peanuts': 'Арахис',
    'fish': 'Рыба',
    'shellfish': 'Моллюски',
    'soy': 'Соя',
    'sesame': 'Кунжут',
    'celery': 'Сельдерей',
    'mustard': 'Горчица',
  };
  return map[code.toLowerCase()] ?? code;
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/core/widgets/app_flushbar.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/presentation/providers/create_plan_notifier.dart';
import 'package:mezzome/features/dishes/presentation/providers/create_plan_state.dart';
import 'package:mezzome/features/dishes/presentation/providers/production_grid_notifier.dart';

/// Экран создания производственного плана (роль `manager`, router-гейт).
/// Состояние держит [CreatePlanNotifier]: справочники, черновик строк,
/// валидация и отправка. Слот строки = категория выбранного блюда.
class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  final _peopleController = TextEditingController();
  final _reserveController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _peopleController.dispose();
    _reserveController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  CreatePlanNotifier get _notifier =>
      ref.read(createPlanNotifierProvider.notifier);

  Future<void> _pickDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateFormatUtil.today,
      lastDate: DateFormatUtil.today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      _notifier.setDate(picked);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final plan = await _notifier.submit();
    if (!mounted) return;
    if (plan == null) {
      final err = ref.read(createPlanNotifierProvider).submitError;
      AppFlushbar.showError(context, err ?? 'createPlanError'.tr());
      return;
    }
    // Предзагружаем недельную сетку на дату плана, чтобы он сразу был виден.
    final date = ref.read(createPlanNotifierProvider).date;
    ref.read(productionGridNotifierProvider.notifier).load(anchorDate: date);
    // Чистим поля-контроллеры под новый план.
    _peopleController.clear();
    _reserveController.clear();
    _notesController.clear();
    _notifier.reset();
    await _showCreatedDialog(plan);
  }

  /// Итог создания. Наличие остатков берём прямо из ответа (`stock_available`
  /// по позициям) — отдельной ручки check-stock у менеджера нет.
  Future<void> _showCreatedDialog(ProductionPlanDetail plan) async {
    final shortages =
        plan.items.where((i) => i.stockAvailable == false).length;
    final stockLine = shortages == 0
        ? 'checkStockOk'.tr()
        : 'checkStockShort'.tr(namedArgs: {'count': '$shortages'});

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('createPlanSuccessTitle'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('createPlanSuccess'.tr()),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  shortages == 0
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: shortages == 0
                      ? AppColors.profitGreen
                      : AppColors.warningAmber,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(stockLine)),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('closeButton'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPlanNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text('createPlanTitle'.tr())),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: state.isBootstrapping
            ? const Center(child: CircularProgressIndicator())
            : state.bootstrapError != null
                ? _BootstrapError(
                    message: state.bootstrapError!,
                    onRetry: _notifier.retryBootstrap,
                  )
                : _buildForm(context, state),
      ),
    );
  }

  Widget _buildForm(BuildContext context, CreatePlanState state) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final categoryById = {for (final c in state.categories) c.id: c};
    final dishById = {for (final d in state.catalog) d.id: d};

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Кухня
              if (state.hasMultipleKitchens)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<int>(
                    initialValue: state.kitchenId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'createPlanKitchenLabel'.tr(),
                    ),
                    items: [
                      for (final k in state.kitchens)
                        DropdownMenuItem(
                          value: k.id,
                          child: Text(k.name ?? '#${k.id}'),
                        ),
                    ],
                    onChanged: _notifier.setKitchen,
                  ),
                )
              else if (state.kitchens.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'createPlanKitchen'.tr(
                      namedArgs: {
                        'kitchen': state.kitchens.first.name ??
                            '#${state.kitchens.first.id}',
                      },
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              // Приём пищи
              SegmentedButton<MenuServiceType>(
                showSelectedIcon: false,
                segments: [
                  for (final s in MenuServiceType.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {state.service},
                onSelectionChanged: (sel) => _notifier.setService(sel.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Дата + число едоков
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(state.date),
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(DateFormatUtil.apiDate(state.date)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _peopleController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'createPlanPeople'.tr(),
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          _notifier.setPeopleCount(int.tryParse(v.trim())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Резерв + заметка
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _reserveController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'createPlanReserve'.tr(),
                        isDense: true,
                        hintText: '1.0',
                      ),
                      onChanged: (v) => _notifier.setReserveCoefficient(
                        double.tryParse(v.trim().replaceAll(',', '.')),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'createPlanNotes'.tr(),
                        isDense: true,
                      ),
                      onChanged: _notifier.setNotes,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'createPlanItemsTitle'.tr(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final item in state.items)
                _PlanItemCard(
                  key: ValueKey(item.key),
                  item: item,
                  dishes: state.catalog,
                  category: _categoryFor(item, dishById, categoryById),
                  onDish: (id) => _notifier.setItemDish(item.key, id),
                  onPortions: (p) => _notifier.setItemPortions(item.key, p),
                  onRemove: state.items.length > 1
                      ? () => _notifier.removeItem(item.key)
                      : null,
                ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: _notifier.addItem,
                icon: const Icon(Icons.add, size: 18),
                label: Text('createPlanAddItem'.tr()),
              ),
              if (state.submitError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _ErrorBanner(message: state.submitError!),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              onPressed: state.canSubmit ? _submit : null,
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text('createPlanSubmit'.tr()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ),
      ],
    );
  }

  MenuCategoryModel? _categoryFor(
    PlanDraftItem item,
    Map<int, DishModel> dishById,
    Map<int, MenuCategoryModel> categoryById,
  ) {
    final dish = item.menuItemId == null ? null : dishById[item.menuItemId];
    final catId = dish?.categoryId;
    return catId == null ? null : categoryById[catId];
  }
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({
    super.key,
    required this.item,
    required this.dishes,
    required this.category,
    required this.onDish,
    required this.onPortions,
    required this.onRemove,
  });

  final PlanDraftItem item;
  final List<DishModel> dishes;
  final MenuCategoryModel? category;
  final ValueChanged<int?> onDish;
  final ValueChanged<int?> onPortions;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
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
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: item.menuItemId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'createPlanDish'.tr(),
                    isDense: true,
                  ),
                  items: [
                    for (final dish in dishes)
                      DropdownMenuItem(
                        value: dish.id,
                        child: Text(
                          dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onDish,
                ),
              ),
              SizedBox(
                width: 96,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: TextFormField(
                    initialValue: item.portions?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'createPlanPortions'.tr(),
                      isDense: true,
                    ),
                    onChanged: (v) => onPortions(int.tryParse(v.trim())),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.dangerRed,
                  onPressed: onRemove,
                ),
            ],
          ),
          if (item.menuItemId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Row(
                children: [
                  Icon(Icons.label_outline, size: 13, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    category?.name ?? 'createPlanSlotNone'.tr(),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.message, required this.onRetry});

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
              Icons.error_outline,
              size: 44,
              color: ThemePalette.onSurfaceMuted(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'createPlanLoadError'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isLight = ThemePalette.isLight(context);
    final bg = isLight
        ? AppColors.dangerRed.withValues(alpha: 0.08)
        : AppColors.dangerRed.withValues(alpha: 0.14);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.dangerRed),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );
  }
}

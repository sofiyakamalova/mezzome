import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:dio/dio.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';

/// Экран создания производственного плана. Открыт роли `manager` (router-гейт);
/// репозиторий разводит ручки по роли: manager → `POST /manager/production-plans`,
/// chef → `POST /chef/production-plans`. Собирается план на день: кухня · приём
/// пищи · дата · позиции (слот · блюдо · порции) → черновик на согласование.
class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _PlanItemDraft {
  _PlanItemDraft();

  int? menuItemId;
  final slotController = TextEditingController();
  final portionsController = TextEditingController();

  void dispose() {
    slotController.dispose();
    portionsController.dispose();
  }
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  MenuServiceType _service = MenuServiceType.lunch;
  DateTime _date = DateFormatUtil.today;
  final _peopleController = TextEditingController();
  final List<_PlanItemDraft> _items = [_PlanItemDraft()];

  List<KitchenModel> _kitchens = const [];
  KitchenModel? _kitchen;
  List<DishModel> _dishes = const [];
  bool _loading = true;
  String? _loadError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _peopleController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(dishesRepositoryProvider);
      final results = await Future.wait([
        repo.planKitchens(),
        repo.fetchCatalogDishes(),
      ]);
      if (!mounted) return;
      final kitchens = results[0] as List<KitchenModel>;
      setState(() {
        _kitchens = kitchens;
        _kitchen = kitchens.isNotEmpty ? kitchens.first : null;
        _dishes = results[1] as List<DishModel>;
        _loading = false;
      });
    } on DioException catch (e) {
      appLogger.w('Create plan bootstrap failed: ${e.response?.statusCode}');
      if (!mounted) return;
      setState(() {
        _loadError = 'createPlanLoadError'.tr();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateFormatUtil.today.subtract(const Duration(days: 1)),
      lastDate: DateFormatUtil.today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _addItem() => setState(() => _items.add(_PlanItemDraft()));

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    final kitchen = _kitchen;
    if (kitchen == null) return;

    // Берём только заполненные позиции (блюдо + порции > 0).
    final inputs = <ProductionPlanItemInput>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final portions = int.tryParse(item.portionsController.text.trim()) ?? 0;
      if (item.menuItemId == null || portions <= 0) continue;
      final slot = item.slotController.text.trim();
      inputs.add(
        ProductionPlanItemInput(
          menuItemId: item.menuItemId!,
          plannedPortions: portions,
          slotKey: 'slot_${i + 1}',
          slotTitle: slot.isEmpty ? null : slot,
          sortOrder: i + 1,
        ),
      );
    }

    if (inputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('createPlanNoItems'.tr())),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(dishesRepositoryProvider);
      final plan = await repo.createProductionPlan(
        ProductionPlanCreateRequest(
          kitchenId: kitchen.id,
          serviceType: _service.apiValue,
          plannedDate: DateFormatUtil.apiDate(_date),
          peopleCount: int.tryParse(_peopleController.text.trim()),
          items: inputs,
        ),
      );
      if (!mounted) return;
      // Сбрасываем форму под новый план.
      setState(() {
        for (final item in _items) {
          item.dispose();
        }
        _items
          ..clear()
          ..add(_PlanItemDraft());
        _peopleController.clear();
        _submitting = false;
      });
      await _showCreatedDialog(plan.id);
    } on DioException catch (e) {
      appLogger.w('Create plan failed: ${e.response?.data}');
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorDetails(e) ?? 'createPlanError'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// После создания: предлагаем проверить остатки (завершающий шаг шефа).
  Future<void> _showCreatedDialog(int planId) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('createPlanSuccessTitle'.tr()),
        content: Text('createPlanSuccess'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('done'),
            child: Text('closeButton'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('check'),
            child: Text('createPlanCheckStock'.tr()),
          ),
        ],
      ),
    );
    if (action == 'check') {
      await _checkStock(planId);
    }
  }

  Future<void> _checkStock(int planId) async {
    try {
      final res = await ref.read(dishesRepositoryProvider).checkStock(planId);
      if (!mounted) return;
      final msg = res.canFulfill
          ? 'checkStockOk'.tr()
          : 'checkStockShort'.tr(namedArgs: {'count': '${res.shortages}'});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on DioException catch (e) {
      appLogger.w('Check stock failed: ${e.response?.data}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorDetails(e) ?? 'checkStockError'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('createPlanTitle'.tr())),
      // Тап по пустому месту убирает фокус → прячет клавиатуру.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(_loadError!, textAlign: TextAlign.center),
                    ),
                  )
                : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (_kitchens.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<int>(
                    initialValue: _kitchen?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'createPlanKitchenLabel'.tr(),
                    ),
                    items: [
                      for (final k in _kitchens)
                        DropdownMenuItem(
                          value: k.id,
                          child: Text(k.name ?? '#${k.id}'),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      _kitchen = _kitchens.firstWhere((k) => k.id == id);
                    }),
                  ),
                )
              else if (_kitchen != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'createPlanKitchen'.tr(
                      namedArgs: {
                        'kitchen': _kitchen!.name ?? '#${_kitchen!.id}',
                      },
                    ),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: muted),
                  ),
                ),
              // Приём пищи
              SegmentedButton<MenuServiceType>(
                showSelectedIcon: false,
                segments: [
                  for (final s in MenuServiceType.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {_service},
                onSelectionChanged: (sel) =>
                    setState(() => _service = sel.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Дата + люди
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(DateFormatUtil.apiDate(_date)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _peopleController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'createPlanPeople'.tr(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'createPlanItemsTitle'.tr(),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: muted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (var i = 0; i < _items.length; i++)
                _PlanItemCard(
                  index: i,
                  item: _items[i],
                  dishes: _dishes,
                  onChanged: () => setState(() {}),
                  onRemove: _items.length > 1 ? () => _removeItem(i) : null,
                ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 18),
                label: Text('createPlanAddItem'.tr()),
              ),
            ],
          ),
        ),
        // Нижняя кнопка отправки
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
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
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({
    required this.index,
    required this.item,
    required this.dishes,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _PlanItemDraft item;
  final List<DishModel> dishes;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      child: Column(
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
                  onChanged: (value) {
                    item.menuItemId = value;
                    onChanged();
                  },
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: item.slotController,
                  decoration: InputDecoration(
                    labelText: 'createPlanSlot'.tr(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: item.portionsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'createPlanPortions'.tr(),
                    isDense: true,
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

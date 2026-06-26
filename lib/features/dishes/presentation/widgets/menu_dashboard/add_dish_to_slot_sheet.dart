import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/config/app_config.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';

/// Шеф: добавить блюдо в слот сетки (категория × день). Создаёт план на дату
/// (`POST /chef/production-plans`) и активирует (`/activate`).
///
/// Показывается как диалог-карточка по центру (а не bottom-sheet): список блюд
/// — ленивый `ListView.builder` в ограниченной по высоте области, поэтому не
/// «зависает» даже на большом каталоге.
class AddDishToSlotSheet extends StatefulWidget {
  const AddDishToSlotSheet({
    super.key,
    required this.date,
    required this.serviceType,
    this.slotKey,
    this.slotTitle = '',
  });

  final DateTime date;
  final String serviceType;
  final String? slotKey;
  final String slotTitle;

  /// Возвращает true, если блюдо добавлено (план создан) — caller перезагружает.
  static Future<bool?> open(
    BuildContext context, {
    required DateTime date,
    required String serviceType,
    String? slotKey,
    String slotTitle = '',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AddDishToSlotSheet(
        date: date,
        serviceType: serviceType,
        slotKey: slotKey,
        slotTitle: slotTitle,
      ),
    );
  }

  @override
  State<AddDishToSlotSheet> createState() => _AddDishToSlotSheetState();
}

class _AddDishToSlotSheetState extends State<AddDishToSlotSheet> {
  final _repo = sl<DishesRepository>();
  final _portions = TextEditingController(text: '1');
  final _search = TextEditingController();

  List<DishModel> _dishes = const [];
  int? _kitchenId;
  DishModel? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _portions.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dishes = await _repo.loadCatalogDishes();
      final kitchens = await _repo.planKitchens();
      if (!mounted) return;
      setState(() {
        _dishes = dishes;
        _kitchenId = kitchens.isEmpty ? null : kitchens.first.id;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorDetails(e) ?? 'Не удалось загрузить блюда';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final dish = _selected;
    final portions = int.tryParse(_portions.text) ?? 0;
    if (dish == null) {
      setState(() => _error = 'Выберите блюдо');
      return;
    }
    if (portions <= 0) {
      setState(() => _error = 'Укажите порции');
      return;
    }
    if (_kitchenId == null) {
      setState(() => _error = 'Не определена кухня');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final plan = await _repo.createProductionPlan(
        ProductionPlanCreateRequest(
          kitchenId: _kitchenId!,
          serviceType: widget.serviceType,
          plannedDate: DateFormatUtil.apiDate(widget.date),
          items: [
            ProductionPlanItemInput(
              menuItemId: dish.id,
              plannedPortions: portions,
              slotKey: widget.slotKey,
              slotTitle: widget.slotTitle.isEmpty ? null : widget.slotTitle,
              sortOrder: 0,
            ),
          ],
        ),
      );
      // Активация — best-effort: план уже создан (черновик). Может упасть 409
      // INSUFFICIENT_STOCK (нет остатков) — это не ошибка добавления.
      String? activateWarning;
      try {
        await _repo.activateChefPlan(plan.id);
      } on DioException catch (e) {
        activateWarning = apiErrorDetails(e) ?? 'не удалось активировать';
        appLogger.w('Plan ${plan.id} activate skipped: $activateWarning');
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(activateWarning == null
            ? 'Блюдо добавлено в план'
            : 'Добавлено (черновик). Активация: $activateWarning'),
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorDetails(e) ?? 'Не удалось добавить блюдо';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Divider(height: 1, color: ThemePalette.border(context)),
            Flexible(child: _body(context)),
            if (_error != null) _errorBar(context),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final title = widget.slotTitle.isEmpty
        ? 'menuAddDish'.tr()
        : widget.slotTitle;
    final dateLabel =
        DateFormatUtil.formatDisplayDate(widget.date, context.locale.toString());
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
          AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(dateLabel, style: TextStyle(color: muted, fontSize: 12.5)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'cancelButton'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_selected != null) {
      return _selectedEditor(context);
    }
    return _picker(context);
  }

  /// Поиск (зафиксирован сверху) + ленивый список блюд (скроллится).
  Widget _picker(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _dishes
        : _dishes.where((d) => d.name.toLowerCase().contains(q)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _search.clear()),
                    ),
              hintText: 'menuDishSearchHint'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Flexible(
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('menuGridEmpty'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Divider(
                      height: 1, color: ThemePalette.border(context)),
                  itemBuilder: (_, i) => _DishRow(
                    dish: filtered[i],
                    onTap: () => setState(() => _selected = filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  /// Выбранное блюдо + ввод порций.
  Widget _selectedEditor(BuildContext context) {
    final accent = ThemePalette.accent(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(children: [
              _DishAvatar(imageUrl: _selected!.imageUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(_selected!.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() => _selected = null),
                child: Text('menuChangeDish'.tr()),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _portions,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'menuPortions'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBar(BuildContext context) {
    final accent = ThemePalette.accent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
      child: Text(_error!, style: TextStyle(color: accent, fontSize: 13)),
    );
  }

  Widget _footer(BuildContext context) {
    final canSave = _selected != null && !_saving;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: FilledButton.icon(
        onPressed: canSave ? _save : null,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text('menuAddDishConfirm'.tr()),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}

/// Абсолютный URL картинки блюда. Бэк может прислать относительный путь
/// (напр. `/uploads/...`) — тогда подставляем origin API (без `/api/v2`).
String? _resolveImageUrl(String? raw) {
  final url = raw?.trim() ?? '';
  if (url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final origin =
      AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  return '$origin${url.startsWith('/') ? '' : '/'}$url';
}

/// Аватар блюда: картинка (если есть), иначе акцентная иконка-плейсхолдер.
class _DishAvatar extends StatelessWidget {
  const _DishAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    final fallback = Container(
      color: accent.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Icon(Icons.restaurant_menu, size: 18, color: accent),
    );
    final url = _resolveImageUrl(imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: SizedBox(
        width: 40,
        height: 40,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                // Даунскейл в памяти — список не «тяжёлый» на большом каталоге.
                cacheWidth: 120,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (ctx, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}

/// Строка блюда в списке выбора: картинка-аватар + название (+ вес).
class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish, required this.onTap});

  final DishModel dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = ThemePalette.onSurfaceMuted(context);
    final weight = dish.weight;
    final subtitle = (weight != null && weight > 0)
        ? '${weight % 1 == 0 ? weight.toStringAsFixed(0) : weight} ${'gramShort'.tr()}'
        : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 10),
        child: Row(
          children: [
            _DishAvatar(imageUrl: dish.imageUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ThemePalette.onSurface(context),
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, size: 20, color: muted),
          ],
        ),
      ),
    );
  }
}

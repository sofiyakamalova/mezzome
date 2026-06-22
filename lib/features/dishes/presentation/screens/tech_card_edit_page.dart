import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';
import 'package:mezzome/features/dishes/data/services/image_upload_service.dart';
import 'package:mezzome/features/dishes/domain/menu_grid_cell.dart';
import 'package:mezzome/features/dishes/domain/tech_card_draft.dart';
import 'package:mezzome/features/dishes/presentation/blocs/menu_dashboard_cubit.dart';
import 'package:mezzome/features/dishes/presentation/widgets/menu_dashboard/ingredient_picker_sheet.dart';

/// Полноэкранный редактор техкарты (заменяет тяжёлый bottom-sheet). Открывается
/// сразу, данные грузятся внутри (без «зависания»). Правит общий черновик в
/// [MenuDashboardCubit] и сохраняет через `saveAndSign`.
class TechCardEditPage extends StatefulWidget {
  const TechCardEditPage({
    super.key,
    this.cell,
    required this.signature,
    required this.showFinancials,
    this.requestContext = false,
    this.create = false,
  });

  /// Ячейка существующей карты (для правки). null в режиме создания.
  final MenuGridCell? cell;
  final String signature;
  final bool showFinancials;
  final bool requestContext;

  /// Режим создания техкарты с нуля (POST).
  final bool create;

  static Future<void> open(
    BuildContext context, {
    required MenuGridCell cell,
    required String signature,
    required bool showFinancials,
    bool requestContext = false,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => TechCardEditPage(
          cell: cell,
          signature: signature,
          showFinancials: showFinancials,
          requestContext: requestContext,
        ),
      ),
    );
  }

  /// Открыть редактор в режиме создания техкарты с нуля.
  static Future<void> openCreate(
    BuildContext context, {
    required String signature,
    required bool showFinancials,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => TechCardEditPage(
          signature: signature,
          showFinancials: showFinancials,
          create: true,
        ),
      ),
    );
  }

  @override
  State<TechCardEditPage> createState() => _TechCardEditPageState();
}

class _TechCardEditPageState extends State<TechCardEditPage> {
  final MenuDashboardCubit _cubit = sl<MenuDashboardCubit>();
  late final Future<List<MenuCategoryModel>> _load = _init();

  Future<List<MenuCategoryModel>> _init() async {
    if (widget.create) {
      _cubit.newDraft();
      // Категории нужны только при создании (для выбора category_id).
      try {
        return await sl<DishesRepository>().fetchMenuCategories();
      } catch (_) {
        return const [];
      }
    }
    await _cubit.selectCell(widget.cell!, requestContext: widget.requestContext);
    return const [];
  }

  @override
  void dispose() {
    _cubit.closeEditor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((widget.create ? 'tcCreateTitle' : 'tcpEdit').tr()),
      ),
      body: FutureBuilder<List<MenuCategoryModel>>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final draft = _cubit.state.editorDraft;
          if (draft == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'tcpNotFound'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
                ),
              ),
            );
          }
          return _EditForm(
            draft: draft,
            cubit: _cubit,
            showFinancials: widget.showFinancials,
            categories: snap.data ?? const [],
            isCreate: widget.create,
          );
        },
      ),
    );
  }
}

class _EditForm extends StatefulWidget {
  const _EditForm({
    required this.draft,
    required this.cubit,
    required this.showFinancials,
    required this.categories,
    required this.isCreate,
  });

  final TechCardDraft draft;
  final MenuDashboardCubit cubit;
  final bool showFinancials;
  final List<MenuCategoryModel> categories;
  final bool isCreate;

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  TechCardDraft get _d => widget.draft;

  late final TextEditingController _name =
      TextEditingController(text: _d.name);
  late final TextEditingController _output =
      TextEditingController(text: _trim(_d.outputGrams));
  late final TextEditingController _portions =
      TextEditingController(text: '${_d.portions}');
  late final TextEditingController _reason =
      TextEditingController(text: _d.editReason);

  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _output.dispose();
    _portions.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _readOnly => _d.readOnly;

  Future<void> _addPhoto() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = res?.files.firstOrNull;
    final bytes = file?.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    final url = await sl<ImageUploadService>()
        .uploadImage(bytes: bytes, filename: file!.name);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _d.photoUrls.add(url);
    });
    if (url == null && mounted) {
      _snack('tcpPhotoUploadError'.tr(), isError: true);
    }
  }

  /// Снэкбар через ScaffoldMessenger (надёжнее flushbar: не пушит роут, не
  /// конфликтует с pop страницы).
  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.dangerRed : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickIngredient(TechCardIngredientDraft row) async {
    final picked = await IngredientPickerSheet.show(context);
    if (picked == null) return;
    setState(() {
      row.ingredientId = picked.id;
      row.name = picked.name;
    });
  }

  Future<void> _save({required bool submit}) async {
    // Синхронизируем поля из контроллеров в черновик.
    _d.name = _name.text.trim();
    _d.outputGrams = double.tryParse(_output.text.replaceAll(',', '.')) ?? _d.outputGrams;
    _d.portions = int.tryParse(_portions.text) ?? _d.portions;
    _d.editReason = _reason.text;
    widget.cubit.updateEditorDraft(_d);

    setState(() => _saving = true);
    final result = await widget.cubit.saveAndSign(submit: submit);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.error != null) {
      _snack(result.error!, isError: true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.notice ??
              (submit ? 'tcSubmittedToast' : 'techCardSavedToast').tr(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (_readOnly)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ReadOnlyBanner(),
                ),
              _PhotoSection(
                urls: _d.photoUrls,
                uploading: _uploading,
                readOnly: _readOnly,
                onAdd: _addPhoto,
                onRemove: (u) => setState(() => _d.photoUrls.remove(u)),
              ),
              const SizedBox(height: AppSpacing.md),
              _Section(
                title: 'tcpSecMain'.tr(),
                child: Column(
                  children: [
                    _Field(
                      label: 'tcpFieldName'.tr(),
                      controller: _name,
                      enabled: !_readOnly,
                    ),
                    if (widget.isCreate && widget.categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<int>(
                        initialValue: _d.categoryId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'tcpFieldCategory'.tr(),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final c in widget.categories)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name ?? '#${c.id}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _d.categoryId = v),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'tcpFieldOutput'.tr(),
                            controller: _output,
                            enabled: !_readOnly,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _Field(
                            label: 'tcpFieldPortions'.tr(),
                            controller: _portions,
                            enabled: !_readOnly,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('tcpFieldHalal'.tr()),
                      value: _d.halalRequired,
                      onChanged: _readOnly
                          ? null
                          : (v) => setState(() => _d.halalRequired = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _IngredientsSection(
                draft: _d,
                readOnly: _readOnly,
                onChanged: () => setState(() {}),
                onPick: _pickIngredient,
              ),
              const SizedBox(height: AppSpacing.md),
              _Section(
                title: 'tcpFieldReason'.tr(),
                child: _Field(
                  label: 'tcpFieldReasonHint'.tr(),
                  controller: _reason,
                  enabled: !_readOnly,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
        if (!_readOnly)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              // Создание: одна кнопка «Создать» — на апрув карта уходит
              // автоматически на бэке. Правка: «Черновик» / «На проверку».
              child: widget.isCreate
                  ? FilledButton.icon(
                      onPressed: _saving ? null : () => _save(submit: false),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text('tcCreate'.tr()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _saving ? null : () => _save(submit: false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text('tcSaveDraft'.tr()),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed:
                                _saving ? null : () => _save(submit: true),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_outlined, size: 18),
                            label: Text('tcSubmit'.tr()),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.urls,
    required this.uploading,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> urls;
  final bool uploading;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'tcpSecPhotos'.tr(),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final u in urls)
            _PhotoTile(url: u, onRemove: readOnly ? null : () => onRemove(u)),
          if (!readOnly)
            InkWell(
              onTap: uploading ? null : onAdd,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: ThemePalette.surfacePanel(context),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: ThemePalette.border(context)),
                ),
                child: uploading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Icon(Icons.add_a_photo_outlined,
                        color: ThemePalette.onSurfaceMuted(context)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.url, this.onRemove});

  final String url;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Image.network(
            url,
            width: 92,
            height: 92,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 92,
              height: 92,
              color: ThemePalette.surfacePanel(context),
              child: Icon(Icons.broken_image_outlined,
                  color: ThemePalette.onSurfaceMuted(context)),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({
    required this.draft,
    required this.readOnly,
    required this.onChanged,
    required this.onPick,
  });

  final TechCardDraft draft;
  final bool readOnly;
  final VoidCallback onChanged;
  final ValueChanged<TechCardIngredientDraft> onPick;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'tcpSecIngredients'.tr(),
      trailing: readOnly
          ? null
          : TextButton.icon(
              onPressed: () {
                draft.ingredients.add(TechCardIngredientDraft());
                onChanged();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text('tcpAddIngredient'.tr()),
            ),
      child: Column(
        children: [
          for (var i = 0; i < draft.ingredients.length; i++)
            _IngredientRow(
              row: draft.ingredients[i],
              readOnly: readOnly,
              onPick: () => onPick(draft.ingredients[i]),
              onChanged: onChanged,
              onRemove: () {
                draft.ingredients.removeAt(i);
                onChanged();
              },
            ),
          if (draft.ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'tcpNoIngredients'.tr(),
                style: TextStyle(color: ThemePalette.onSurfaceMuted(context)),
              ),
            ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.row,
    required this.readOnly,
    required this.onPick,
    required this.onChanged,
    required this.onRemove,
  });

  final TechCardIngredientDraft row;
  final bool readOnly;
  final VoidCallback onPick;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: readOnly ? null : onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: row.ingredientId == null
                        ? AppColors.dangerRed.withValues(alpha: 0.5)
                        : ThemePalette.border(context),
                  ),
                ),
                child: Text(
                  row.name.isEmpty ? 'tcpPickIngredient'.tr() : row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: row.name.isEmpty
                        ? ThemePalette.onSurfaceMuted(context)
                        : ThemePalette.onSurface(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _NumField(
              hint: 'tcpBrutto'.tr(),
              value: row.brutto,
              enabled: !readOnly,
              onChanged: (v) {
                row.brutto = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _NumField(
              hint: 'tcpNetto'.tr(),
              value: row.netto,
              enabled: !readOnly,
              onChanged: (v) {
                row.netto = v;
                onChanged();
              },
            ),
          ),
          if (!readOnly)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.dangerRed,
            ),
        ],
      ),
    );
  }
}

class _NumField extends StatefulWidget {
  const _NumField({
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String hint;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value == 0 ? '' : _fmt(widget.value),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: const OutlineInputBorder(),
      ),
      onChanged: (s) =>
          widget.onChanged(double.tryParse(s.replaceAll(',', '.')) ?? 0),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
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

class _ReadOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.warningAmber),
          const SizedBox(width: 8),
          Expanded(child: Text('tcpReadOnly'.tr())),
        ],
      ),
    );
  }
}

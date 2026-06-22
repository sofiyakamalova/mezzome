import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/features/inventory/data/ingredient_create_service.dart';

/// Создание ингредиента в справочник (owner/admin). Минимальная форма.
class CreateIngredientScreen extends StatefulWidget {
  const CreateIngredientScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateIngredientScreen()),
    );
  }

  @override
  State<CreateIngredientScreen> createState() => _CreateIngredientScreenState();
}

class _CreateIngredientScreenState extends State<CreateIngredientScreen> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  String _unit = 'kg';
  bool _saving = false;

  // value = canonical unit code (бэк требует kg/gr/l/ml/pieces), label = UI.
  static const _units = <({String code, String label})>[
    (code: 'kg', label: 'кг'),
    (code: 'gr', label: 'г'),
    (code: 'l', label: 'л'),
    (code: 'ml', label: 'мл'),
    (code: 'pieces', label: 'шт'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _price.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.dangerRed : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('ingNameRequired'.tr(), isError: true);
      return;
    }
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      _snack('ingPriceRequired'.tr(), isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await sl<IngredientCreateService>().create(
        name: name,
        category: _category.text.trim(),
        unit: _unit,
        price: price,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('ingCreatedToast'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(apiErrorDetails(e) ?? 'ingCreateError'.tr(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ingCreateTitle'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: '${'ingName'.tr()} *',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: InputDecoration(
                    labelText: '${'ingUnit'.tr()} *',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final u in _units)
                      DropdownMenuItem(value: u.code, child: Text(u.label)),
                  ],
                  onChanged: (v) => setState(() => _unit = v ?? _unit),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${'ingPrice'.tr()} *',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _category,
            decoration: InputDecoration(
              labelText: 'ingCategory'.tr(),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text('ingCreate'.tr()),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/data/models/ingredient_catalog_model.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';

/// Лист выбора ингредиента из справочника кухни. Возвращает выбранный
/// [IngredientCatalogItem] (или `null`, если закрыли без выбора).
class IngredientPickerSheet extends StatefulWidget {
  const IngredientPickerSheet({super.key});

  static Future<IngredientCatalogItem?> show(BuildContext context) {
    return showModalBottomSheet<IngredientCatalogItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IngredientPickerSheet(),
    );
  }

  @override
  State<IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<IngredientPickerSheet> {
  String _query = '';
  late Future<List<IngredientCatalogItem>> _future =
      sl<MenuDashboardRepository>().loadIngredientCatalog();

  void _reload() {
    setState(() {
      _future = sl<MenuDashboardRepository>().loadIngredientCatalog();
    });
  }

  List<IngredientCatalogItem> _filter(List<IngredientCatalogItem> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.8;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: height,
        child: Material(
          color: ThemePalette.surfacePanel(context),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemePalette.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ingredientPickerTitle'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ingredientPickerSearchHint'.tr(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: FutureBuilder<List<IngredientCatalogItem>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(onRetry: _reload);
                    }
                    final items = snapshot.data ?? const [];
                    final filtered = _filter(items);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'ingredientPickerEmpty'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: ThemePalette.onSurfaceMuted(context),
                              ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final subtitle = [
                          if (item.category != null) item.category!,
                          if (item.unit != null) item.unit!,
                        ].join(' · ');
                        return ListTile(
                          dense: true,
                          title: Text(item.name),
                          subtitle:
                              subtitle.isEmpty ? null : Text(subtitle),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ingredientPickerError'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text('retryButton'.tr()),
          ),
        ],
      ),
    );
  }
}

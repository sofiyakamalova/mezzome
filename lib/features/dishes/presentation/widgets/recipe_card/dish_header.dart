import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'recipe_models.dart';
import 'common_widgets.dart';

/// Левый верхний блок: миниатюра, название, чипы категорий, даты.
class DishHeader extends StatelessWidget {
  final RecipeCard recipe;
  const DishHeader({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Thumbnail(url: recipe.images.isNotEmpty ? recipe.images.first : null),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(recipe.title, style: AppText.h1),
              const SizedBox(height: 12),
              const Text('Категории', style: AppText.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recipe.categories
                    .map((c) => CategoryChip(label: c))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(recipe.createdInfo, style: _meta),
              const SizedBox(height: 3),
              Text(recipe.updatedInfo, style: _meta),
            ],
          ),
        ),
      ],
    );
  }

  static const TextStyle _meta = TextStyle(
    fontSize: 12.5,
    color: AppColors.textMuted,
    height: 1.4,
  );
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.image),
      child: SizedBox(
        width: 140,
        height: 140,
        child: url == null
            ? Container(color: AppColors.placeholder)
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: AppColors.placeholder),
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : Container(
                        color: AppColors.draftBg,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
              ),
      ),
    );
  }
}

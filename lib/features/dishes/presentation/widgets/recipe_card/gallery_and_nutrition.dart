import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'recipe_models.dart';

/// Сетка фото 2x2. На последней ячейке — затемнение с «Смотреть все».
class PhotoGallery extends StatelessWidget {
  final List<String> images;
  final VoidCallback? onSeeAll;
  const PhotoGallery({super.key, required this.images, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final shown = images.take(4).toList();
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(shown.length, (i) {
        final isLast = i == shown.length - 1;
        return _GalleryTile(
          url: shown[i],
          overlayLabel: isLast ? 'Смотреть все' : null,
          onTap: isLast ? onSeeAll : null,
        );
      }),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final String url;
  final String? overlayLabel;
  final VoidCallback? onTap;
  const _GalleryTile({required this.url, this.overlayLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.image),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppColors.placeholder),
            loadingBuilder: (ctx, child, p) => p == null
                ? child
                : Container(color: AppColors.draftBg),
          ),
          if (overlayLabel != null)
            Material(
              color: Colors.black.withValues(alpha: 0.45),
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Text(
                    overlayLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Блок «Пищевая ценность 1 порции» — карточка с 4 колонками.
class NutritionPanel extends StatelessWidget {
  final Nutrition nutrition;
  const NutritionPanel({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final entries = <List<String>>[
      ['Белки', nutrition.protein],
      ['Жиры', nutrition.fat],
      ['Углеводы', nutrition.carbs],
      ['Калории', nutrition.calories],
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: entries
            .map(
              (e) => Expanded(
                child: Column(
                  children: [
                    Text(e[0], style: AppText.label),
                    const SizedBox(height: 10),
                    Text(
                      e[1],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

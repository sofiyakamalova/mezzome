import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Чип категории (например «Горячие блюда»).
class CategoryChip extends StatelessWidget {
  final String label;
  const CategoryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.chipBorder),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(label, style: AppText.chip),
    );
  }
}

/// Карточка-метрика: подпись сверху, крупное значение снизу.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  const StatCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 10),
          Text(value, style: AppText.valueBig),
        ],
      ),
    );
  }
}

/// Заголовок секции на голубой плашке («Технология приготовления»).
class SectionHeaderBanner extends StatelessWidget {
  final String title;
  const SectionHeaderBanner({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(title, style: AppText.sectionTitle),
    );
  }
}

/// Обычный заголовок секции («Рецептура», «История изменений»).
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppText.sectionTitle);
  }
}

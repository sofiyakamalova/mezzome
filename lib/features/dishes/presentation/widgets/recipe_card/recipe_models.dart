import 'package:flutter/material.dart';

/// Строка рецептуры (ингредиент).
class Ingredient {
  final int number;
  final String product;
  final int grossG;
  final int netG;
  final String lossPercent;
  final String pricePerKg;
  final String sum;

  const Ingredient({
    required this.number,
    required this.product,
    required this.grossG,
    required this.netG,
    required this.lossPercent,
    required this.pricePerKg,
    required this.sum,
  });
}

/// Пункт технологии приготовления.
class TechStep {
  final String title;
  final String description;

  const TechStep({required this.title, required this.description});
}

/// Требование к качеству.
class QualityRequirement {
  final String label;
  final String value;

  const QualityRequirement({required this.label, required this.value});
}

/// Запись в истории изменений.
class HistoryEntry {
  final String date;
  final String role;
  final String author;
  final String action;
  final String? detail;
  final Color roleColor;

  const HistoryEntry({
    required this.date,
    required this.role,
    required this.author,
    required this.action,
    this.detail,
    required this.roleColor,
  });
}

/// Пищевая ценность.
class Nutrition {
  final String protein;
  final String fat;
  final String carbs;
  final String calories;

  const Nutrition({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.calories,
  });
}

/// Вся техкарта.
class RecipeCard {
  final String title;
  final List<String> categories;
  final String createdInfo;
  final String updatedInfo;
  final String portionOutput;
  final String portionsCount;
  final String costPerPortion;
  final List<Ingredient> ingredients;
  final List<String> images;
  final Nutrition nutrition;
  final List<TechStep> technology;
  final List<QualityRequirement> quality;
  final List<HistoryEntry> history;

  const RecipeCard({
    required this.title,
    required this.categories,
    required this.createdInfo,
    required this.updatedInfo,
    required this.portionOutput,
    required this.portionsCount,
    required this.costPerPortion,
    required this.ingredients,
    required this.images,
    required this.nutrition,
    required this.technology,
    required this.quality,
    required this.history,
  });
}

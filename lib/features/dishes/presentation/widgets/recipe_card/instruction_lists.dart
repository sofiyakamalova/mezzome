import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'recipe_models.dart';

/// Нумерованный список шагов технологии приготовления.
class TechnologyList extends StatelessWidget {
  final List<TechStep> steps;
  const TechnologyList({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
            child: RichText(
              text: TextSpan(
                style: AppText.body,
                children: [
                  TextSpan(
                    text: '${i + 1}. ',
                    style: AppText.bodyBold,
                  ),
                  TextSpan(
                    text: '${steps[i].title} ',
                    style: AppText.bodyBold,
                  ),
                  TextSpan(text: steps[i].description),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Нумерованный список требований к качеству (label жирным).
class QualityList extends StatelessWidget {
  final List<QualityRequirement> requirements;
  const QualityList({super.key, required this.requirements});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < requirements.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i == requirements.length - 1 ? 0 : 14),
            child: RichText(
              text: TextSpan(
                style: AppText.body,
                children: [
                  TextSpan(text: '${i + 1}. ', style: AppText.bodyBold),
                  TextSpan(
                    text: '${requirements[i].label} ',
                    style: AppText.bodyBold,
                  ),
                  TextSpan(text: requirements[i].value),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

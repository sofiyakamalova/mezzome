import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';

/// Проверяем, что модель парсит новый контракт техкарты:
/// cooking_steps, комменты ингредиентов, КБЖУ, себестоимость.
void main() {
  Map<String, dynamic> payload() => {
        'id': 994170,
        'name': 'плов',
        'category_id': 990201,
        'category_name': 'DEV Catering Dishes',
        'base_portions': 509,
        'output_per_portion': 450,
        'output_unit': 'g',
        'halal_required': false,
        'status': 'approved',
        'approval_status': 'approved',
        'total_ingredient_cost': 2306.9858,
        'stored_total_ingredient_cost': 41700,
        'calculated_total_ingredient_cost': 2306.9858,
        'food_cost': 4.5324,
        'nutrition_total': {'calories_kcal': 4.1, 'protein_g': 0.09},
        'nutrition_per_portion': {'calories_kcal': 0.0081},
        'compliance_summary': {
          'allergens': ['celery'],
          'halal_compliant': true,
          'nutrition_per_portion': {'calories_kcal': 0.0081, 'protein_g': 0.0002},
          'nutrition_total': {'calories_kcal': 4.1, 'protein_g': 0.09},
        },
        'ingredients': [
          {
            'id': 994034,
            'ingredient_id': 990401,
            'ingredient_name': 'DEV Beef raw',
            'unit': 'kg',
            'brutto': 14,
            'netto': 12.32,
            'cost_per_unit': 32.08,
            'total_cost': 320.77,
            'cleaning_pct': 12,
            'cut_type': 'large_dice',
            'chef_comment': 'Нарезать крупно',
            'prep_comment': 'Зачистить жилы',
            'cooking_comment': 'Сначала обжарить',
            'method_hint': 'stew',
            'target_output': 'мягкое мясо',
          },
        ],
        'cooking_steps': [
          {
            'id': 1,
            'step_order': 1,
            'title': 'Тушение мяса',
            'instruction': 'Тушить до мягкости',
            'cooking_method_id': 1,
            'method_code': 'stew',
            'method_name': 'Тушение',
            'equipment_id': 2,
            'equipment_code': 'cooking_kettle',
            'equipment_name': 'Варочный котёл',
            'temperature_c': 95,
            'duration_minutes': 90,
            'humidity_pct': 60,
            'stage': 'cook',
            'ingredient_refs': [990401],
            'notes': 'Контролировать',
            'chef_comment': 'Не пересушить',
          },
        ],
      };

  test('парсит cooking_steps (метод/оборудование/режим/ingredient_refs)', () {
    final card = TechnicalCardModel.fromJson(payload());

    expect(card.cookingSteps, hasLength(1));
    final s = card.cookingSteps.single;
    expect(s.stepOrder, 1);
    expect(s.title, 'Тушение мяса');
    expect(s.methodName, 'Тушение');
    expect(s.equipmentName, 'Варочный котёл');
    expect(s.temperatureC, 95);
    expect(s.durationMinutes, 90);
    expect(s.humidityPct, 60);
    expect(s.stage, 'cook');
    expect(s.ingredientRefs, [990401]);
    expect(s.chefComment, 'Не пересушить');
  });

  test('парсит комменты ингредиента (cut_type/chef/prep/cooking/target)', () {
    final card = TechnicalCardModel.fromJson(payload());

    final ing = card.ingredients.single;
    expect(ing.cutType, 'large_dice');
    expect(ing.chefComment, 'Нарезать крупно');
    expect(ing.prepComment, 'Зачистить жилы');
    expect(ing.cookingComment, 'Сначала обжарить');
    expect(ing.methodHint, 'stew');
    expect(ing.targetOutput, 'мягкое мясо');
  });

  test('парсит КБЖУ и себестоимость', () {
    final card = TechnicalCardModel.fromJson(payload());

    expect(card.totalIngredientCost, 2306.9858);
    expect(card.compliance?.allergens, ['celery']);
    expect(card.compliance?.nutritionPerPortion['calories_kcal'], 0.0081);
    expect(card.compliance?.nutritionTotal['protein_g'], 0.09);
  });

  test('пустой cooking_steps парсится в []', () {
    final json = payload()..['cooking_steps'] = <dynamic>[];
    final card = TechnicalCardModel.fromJson(json);
    expect(card.cookingSteps, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';

void main() {
  group('ProductionPlanDetail.fromJson', () {
    test('parses full create response incl. decimal-string costs and slots', () {
      // Форма ответа `dto.ProductionPlanResponse` (POST 201).
      final json = <String, dynamic>{
        'id': 42,
        'status': 'draft',
        'service_type': 'lunch',
        'planned_date': '2026-06-14',
        'kitchen_id': 990011,
        'people_count': 350,
        'reserve_coefficient': '1.10',
        'notes': 'тест',
        'items': [
          {
            'id': 1,
            'plan_id': 42,
            'menu_item_id': 101,
            'planned_portions': 200,
            'theoretical_cost': '1500.0000', // Decimal-строка
            'slot_key': 'category_2',
            'slot_title': 'Основное',
            'sort_order': 1,
            'stock_available': true,
          },
          {
            'id': 2,
            'plan_id': 42,
            'menu_item_id': 102,
            'planned_portions': 150,
            'theoretical_cost': 800.5, // число
            'slot_key': 'category_3',
            'slot_title': 'Гарнир',
            'sort_order': 2,
            'stock_available': false,
          },
        ],
      };

      final plan = ProductionPlanDetail.fromJson(json);

      expect(plan.id, 42);
      expect(plan.status, 'draft');
      expect(plan.kitchenId, 990011);
      expect(plan.peopleCount, 350);
      expect(plan.reserveCoefficient, 1.10);
      expect(plan.items, hasLength(2));

      final first = plan.items.first;
      expect(first.slotTitle, 'Основное');
      expect(first.sortOrder, 1);
      expect(first.theoreticalCost, 1500.0); // строка распарсилась
      expect(first.stockAvailable, true);

      // Агрегаты считаются из позиций.
      expect(plan.totalPortions, 350);
      expect(plan.totalCost, 2300.5);
    });

    test('tolerates missing optional fields', () {
      final plan = ProductionPlanDetail.fromJson({'id': 7});
      expect(plan.id, 7);
      expect(plan.items, isEmpty);
      expect(plan.totalCost, 0);
      expect(plan.kitchenId, isNull);
    });
  });

  group('ProductionPlanStockCheck.fromJson', () {
    test('parses can_fulfill, shortages and decimal-string total', () {
      final json = <String, dynamic>{
        'can_fulfill': false,
        'total_cost': '12345.6700',
        'shortages': [
          {
            'ingredient': 'Говядина',
            'ingredient_id': 5,
            'required_qty': '30.0',
            'available_qty': 10,
            'deficit_qty': '20.0',
            'unit': 'kg',
          },
        ],
        'warnings': ['low_stock'],
      };

      final result = ProductionPlanStockCheck.fromJson(json);

      expect(result.canFulfill, false);
      expect(result.totalCost, 12345.67);
      expect(result.shortages, hasLength(1));
      expect(result.shortages.first.ingredient, 'Говядина');
      expect(result.shortages.first.deficitQty, 20.0);
      expect(result.warnings, contains('low_stock'));
    });

    test('empty response is a valid "can fulfill / no shortages" state', () {
      final result = ProductionPlanStockCheck.fromJson({'can_fulfill': true});
      expect(result.canFulfill, true);
      expect(result.shortages, isEmpty);
      expect(result.totalCost, 0);
    });
  });
}

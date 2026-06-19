import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/warehouse/data/dtos/warehouse_dashboard_dto.dart';
import 'package:mezzome/features/warehouse/domain/behaviors/warehouse_behavior.dart';
import 'package:mezzome/features/warehouse/domain/use_cases/get_warehouse_dashboard_use_case.dart';
import 'package:mezzome/features/warehouse/presentation/blocs/warehouse_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockBehavior extends Mock implements WarehouseBehavior {}

final _sample = WarehouseDashboardDto.fromJson(const {
  'permissions': {'can_view_money': true},
  'summary': {
    'inventory_purchases': 1000000,
    'low_stock_count': 2,
    'stock_health_pct': 72.5,
  },
  'budget_variance': [
    {'category': 'food', 'actual': 600000, 'target': 500000, 'delta': 100000},
  ],
  'low_stock_items': [
    {'id': 1, 'name': 'Мука', 'status': 'critical'},
  ],
  'meal_cost_rows': [
    {'date_label': '01.06', 'total_cost': 300000, 'cost_per_meal': 1200, 'swipes': 250},
  ],
});

void main() {
  late _MockBehavior behavior;
  late GetWarehouseDashboardUseCase useCase;

  setUp(() {
    behavior = _MockBehavior();
    useCase = GetWarehouseDashboardUseCase(behavior);
  });

  group('WarehouseDashboardDto', () {
    test('parses decimal-tolerant fields, statuses, no fake meat/fruit split', () {
      expect(_sample.summary.inventoryPurchases, 1000000);
      expect(_sample.summary.lowStockCount, 2);
      expect(_sample.lowStockItems.single.isCritical, isTrue);
      expect(_sample.budgetVariance.single.delta, 100000);
      expect(_sample.mealCostRows.single.costPerMeal, 1200);
    });

    test('empty json → safe empty dashboard', () {
      final d = WarehouseDashboardDto.fromJson(const {});
      expect(d.lowStockItems, isEmpty);
      expect(d.summary.inventoryPurchases, 0);
      expect(d.canViewMoney, isTrue);
    });
  });

  group('WarehouseBloc', () {
    blocTest<WarehouseBloc, WarehouseState>(
      'Requested → [loading, success] with data',
      setUp: () => when(
        () => behavior.getWarehouse(
          period: any(named: 'period'),
          date: any(named: 'date'),
          mealPeriod: any(named: 'mealPeriod'),
        ),
      ).thenAnswer((_) async => _sample),
      build: () => WarehouseBloc(useCase),
      act: (b) => b.add(const WarehouseRequested()),
      expect: () => [
        isA<WarehouseState>()
            .having((s) => s.status, 'status', WarehouseStatus.loading),
        isA<WarehouseState>()
            .having((s) => s.status, 'status', WarehouseStatus.success)
            .having((s) => s.data, 'data', isNotNull),
      ],
    );

    blocTest<WarehouseBloc, WarehouseState>(
      'null from behavior → [loading, failure] (best-effort)',
      setUp: () => when(
        () => behavior.getWarehouse(
          period: any(named: 'period'),
          date: any(named: 'date'),
          mealPeriod: any(named: 'mealPeriod'),
        ),
      ).thenAnswer((_) async => null),
      build: () => WarehouseBloc(useCase),
      act: (b) => b.add(const WarehouseRequested()),
      expect: () => [
        isA<WarehouseState>()
            .having((s) => s.status, 'status', WarehouseStatus.loading),
        isA<WarehouseState>()
            .having((s) => s.status, 'status', WarehouseStatus.failure)
            .having((s) => s.data, 'data', isNull),
      ],
    );

    blocTest<WarehouseBloc, WarehouseState>(
      'PeriodChanged updates period and reloads',
      setUp: () => when(
        () => behavior.getWarehouse(
          period: any(named: 'period'),
          date: any(named: 'date'),
          mealPeriod: any(named: 'mealPeriod'),
        ),
      ).thenAnswer((_) async => _sample),
      build: () => WarehouseBloc(useCase),
      act: (b) => b.add(const WarehousePeriodChanged('month')),
      expect: () => [
        isA<WarehouseState>().having((s) => s.period, 'period', 'month'),
        isA<WarehouseState>()
            .having((s) => s.status, 'status', WarehouseStatus.loading),
        isA<WarehouseState>()
            .having((s) => s.status, 'status', WarehouseStatus.success),
      ],
      verify: (_) => verify(
        () => behavior.getWarehouse(
          period: 'month',
          date: any(named: 'date'),
          mealPeriod: any(named: 'mealPeriod'),
        ),
      ).called(1),
    );
  });
}

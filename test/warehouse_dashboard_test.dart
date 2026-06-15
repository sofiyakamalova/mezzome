import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/dashboard/data/api/dashboard_api.dart';
import 'package:mezzome/features/dashboard/data/models/branch_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/financial_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/warehouse_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';
import 'package:mezzome/features/dashboard/presentation/providers/warehouse_dashboard_notifier.dart';

const _warehouseJson = <String, dynamic>{
  'permissions': {'can_view_money': true},
  'summary': {
    'inventory_spend': '1000000.0000', // Decimal-строка
    'inventory_purchases': 1000000,
    'inventory_consumption': 750000,
    'food_cost': 600000,
    'non_food_spend': 400000,
    'waste_loss': 50000,
    'low_stock_count': 2,
    'stock_health_pct': 72.5,
  },
  'budget_variance': [
    {
      'category': 'food',
      'actual': 600000,
      'target': 500000,
      'delta': 100000,
      'deviation_pct': 20,
    },
  ],
  'low_stock_items': [
    {
      'id': 1,
      'name': 'Мука',
      'unit': 'кг',
      'current_stock': 5,
      'min_required': 20,
      'status': 'critical',
    },
    {
      'id': 2,
      'name': 'Соль',
      'unit': 'кг',
      'current_stock': 15,
      'min_required': 20,
      'status': 'low',
    },
  ],
  'category_chart': [
    {'category': 'food', 'value': 600000},
    {'category': 'paper_supplies', 'value': 0},
  ],
  'meal_cost_rows': [
    {
      'date_label': '01.06',
      'total_cost': 300000,
      'cost_per_meal': 1200,
      'swipes': 250,
      // фиктивные поля бэка — модель их игнорирует
      'meats_fish_cost': 300000,
      'meats_fish_pct': 100,
      'fruits_cost': 0,
      'fruits_pct': 0,
    },
  ],
  'daily_spend_rows': [
    {
      'date_label': '01.06',
      'food': 300000,
      'janitorials': 10000,
      'paper_supplies': 5000,
      'disposables': 4000,
      'light_equipment': 1000,
    },
  ],
};

class _FakeRepo extends DashboardRepository {
  _FakeRepo({this.warehouse}) : super(DashboardApi(Dio()));

  final WarehouseDashboard? warehouse;

  @override
  Future<WarehouseDashboard?> fetchWarehouse({
    required String period,
    required String date,
    String? mealPeriod,
  }) async => warehouse;

  // Не используется в этих тестах, но нужно для полноты контракта.
  @override
  Future<FinancialDashboard> fetchFinancialDashboard({
    required String period,
    required String date,
  }) async => FinancialDashboard.fromJson(const {});

  @override
  Future<BranchDashboard> fetchBranches({
    required String period,
    required String date,
  }) async => BranchDashboard.fromJson(const {});

  @override
  Future<ExpensesDashboardModel> fetchExpenses({
    required String period,
    required String date,
  }) async => ExpensesDashboardModel.fromJson(const {});
}

void main() {
  group('WarehouseDashboard.fromJson', () {
    test('parses summary, decimal strings, statuses', () {
      final d = WarehouseDashboard.fromJson(_warehouseJson);
      expect(d.canViewMoney, isTrue);
      expect(d.summary.inventorySpend, 1000000);
      expect(d.summary.lowStockCount, 2);
      expect(d.summary.stockHealthPct, 72.5);
      expect(d.budgetVariance.single.delta, 100000); // перерасход
      expect(d.lowStockItems[0].isCritical, isTrue);
      expect(d.lowStockItems[1].isCritical, isFalse);
      expect(d.mealCostRows.single.totalCost, 300000);
      expect(d.mealCostRows.single.swipes, 250);
    });

    test('meal cost row exposes only total/cpm/swipes (no fake split)', () {
      final row = WarehouseDashboard.fromJson(_warehouseJson).mealCostRows.single;
      // У модели нет полей meats_fish/fruits — гайд §9 запрещает фейковую разбивку.
      expect(row.costPerMeal, 1200);
      expect(row.totalCost, 300000);
    });

    test('empty json yields safe empty dashboard', () {
      final d = WarehouseDashboard.fromJson(const {});
      expect(d.budgetVariance, isEmpty);
      expect(d.lowStockItems, isEmpty);
      expect(d.summary.inventorySpend, 0);
      expect(d.canViewMoney, isTrue);
    });
  });

  group('WarehouseDashboardNotifier', () {
    test('returns warehouse data via repository', () async {
      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            _FakeRepo(warehouse: WarehouseDashboard.fromJson(_warehouseJson)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final data =
          await container.read(warehouseDashboardNotifierProvider.future);
      expect(data, isNotNull);
      expect(data!.lowStockItems, hasLength(2));
    });

    test('null from repo (best-effort) does not throw', () async {
      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(_FakeRepo()),
        ],
      );
      addTearDown(container.dispose);
      final data =
          await container.read(warehouseDashboardNotifierProvider.future);
      expect(data, isNull);
    });
  });
}

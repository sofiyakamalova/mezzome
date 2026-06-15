import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/dashboard/data/api/dashboard_api.dart';
import 'package:mezzome/features/dashboard/data/models/branch_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/expenses_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/financial_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';
import 'package:mezzome/features/dashboard/presentation/providers/branches_dashboard_notifier.dart';

const _branchesJson = <String, dynamic>{
  'period': 'week',
  'date': '2026-06-13',
  'permissions': {'can_view_money': true},
  'branches': [
    {
      'id': 1,
      'name': 'Catering 1',
      'short_label': 'C1',
      'revenue': '1000000.0000', // Decimal-строка
      'cost': 300000,
      'gross_profit': 700000,
      'gross_margin_pct': 70,
      'opex_total': 200000,
      'net_profit': 500000,
      'orders_count': 120,
    },
    {
      'id': 2,
      'name': 'Catering 2',
      'short_label': 'C2',
      'revenue': 400000,
      'cost': 150000,
      'gross_profit': 250000,
      'gross_margin_pct': 62.5,
      // opex_total и net_profit отсутствуют — проверяем nullable + fallback.
      'orders_count': 50,
    },
  ],
  'totals': {
    'revenue': 1400000,
    'cost': 450000,
    'gross_profit': 950000,
    'gross_margin_pct': 67.8,
    'unallocated_opex': 80000,
    'opex_total': 330000,
    'net_profit': 620000,
  },
};

const _expensesJson = <String, dynamic>{
  'total': 330000,
  'by_category': {'wage': 250000, 'electricity': 80000},
  'by_branch': [
    {
      'branch_id': 1,
      'total': 200000,
      'by_category': {'wage': 150000, 'electricity': 50000},
    },
    {
      'branch_id': 2,
      'total': 50000,
      'by_category': {'wage': 50000},
    },
  ],
  'available_categories': ['wage', 'electricity'],
};

class _FakeRepo extends DashboardRepository {
  _FakeRepo() : super(DashboardApi(Dio()));

  @override
  Future<FinancialDashboard> fetchFinancialDashboard({
    required String period,
    required String date,
  }) async => FinancialDashboard.fromJson(const {});

  @override
  Future<BranchDashboard> fetchBranches({
    required String period,
    required String date,
  }) async => BranchDashboard.fromJson(_branchesJson);

  @override
  Future<ExpensesDashboardModel> fetchExpenses({
    required String period,
    required String date,
  }) async => ExpensesDashboardModel.fromJson(_expensesJson);
}

void main() {
  group('BranchDashboard.fromJson', () {
    test('parses rows, decimal strings and nullable opex/net_profit', () {
      final d = BranchDashboard.fromJson(_branchesJson);
      expect(d.canViewMoney, isTrue);
      expect(d.branches, hasLength(2));
      expect(d.branches[0].revenue, 1000000);
      expect(d.branches[0].netProfit, 500000);
      expect(d.branches[1].opexTotal, isNull);
      expect(d.branches[1].netProfit, isNull);
      expect(d.totals.unallocatedOpex, 80000);
    });
  });

  group('ExpensesDashboardModel.by_branch', () {
    test('parses per-branch category breakdown', () {
      final e = ExpensesDashboardModel.fromJson(_expensesJson);
      expect(e.byBranch, hasLength(2));
      expect(e.byBranch[0].branchId, 1);
      expect(e.byBranch[0].byCategory['wage'], 150000);
      expect(e.byBranch[0].total, 200000);
    });
  });

  group('BranchesDashboardNotifier merge', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(_FakeRepo()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('builds All aggregate + per-branch cards with expense breakdown',
        () async {
      final data =
          await container.read(branchesDashboardNotifierProvider.future);

      // All + 2 объекта.
      expect(data.objects, hasLength(3));
      final all = data.objects.firstWhere((o) => o.isAll);
      expect(all.revenue, 1400000);
      expect(all.unallocatedOpex, 80000);
      // Полная разбивка из верхнеуровневого by_category (включая зарплату,
      // которая сидит в нераспределённых и отсутствует в by_branch).
      expect(all.expensesByCategory['wage'], 250000);
      expect(all.expensesTotal, 330000); // totals.opex_total
      expect(all.netProfit, 620000); // из totals.net_profit

      final c1 = data.objects.firstWhere((o) => o.id == 1);
      expect(c1.name, 'Catering 1');
      expect(c1.expensesByCategory['electricity'], 50000);
      expect(c1.netProfit, 500000);
    });

    test('net profit falls back to revenue-cost-expenses when backend null',
        () async {
      final data =
          await container.read(branchesDashboardNotifierProvider.future);
      final c2 = data.objects.firstWhere((o) => o.id == 2);
      // opex_total/net_profit отсутствовали → fallback на сумму расходов филиала.
      expect(c2.expensesTotal, 50000); // exp.total из by_branch
      expect(c2.netProfit, 400000 - 150000 - 50000); // 200000
    });

    test('selecting a branch filters visible cards', () async {
      await container.read(branchesDashboardNotifierProvider.future);
      container.read(branchesDashboardNotifierProvider.notifier).setBranch(1);
      final data = container.read(branchesDashboardNotifierProvider).value!;
      expect(data.visible, hasLength(1));
      expect(data.visible.single.id, 1);
    });
  });
}

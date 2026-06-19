import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/branches/data/dtos/branch_dashboard_dto.dart';
import 'package:mezzome/features/branches/data/dtos/expenses_breakdown_dto.dart';
import 'package:mezzome/features/branches/domain/behaviors/branches_behavior.dart';
import 'package:mezzome/features/branches/domain/models/branch_dashboard.dart';
import 'package:mezzome/features/branches/domain/models/expenses_breakdown.dart';
import 'package:mezzome/features/branches/domain/use_cases/get_objects_finance_use_case.dart';
import 'package:mezzome/features/branches/presentation/blocs/branches_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockBehavior extends Mock implements BranchesBehavior {}

final _branches = BranchDashboardDto.fromJson(const {
  'permissions': {'can_view_money': true},
  'branches': [
    {
      'id': 1,
      'name': 'Catering 1',
      'revenue': '1000000.0000',
      'cost': 300000,
      'gross_profit': 700000,
      'opex_total': 200000,
      'net_profit': 500000,
      'orders_count': 120,
    },
    {
      'id': 2,
      'name': 'Catering 2',
      'revenue': 400000,
      'cost': 150000,
      // opex_total/net_profit отсутствуют → fallback
      'orders_count': 50,
    },
  ],
  'totals': {
    'revenue': 1400000,
    'cost': 450000,
    'unallocated_opex': 80000,
    'opex_total': 330000,
    'net_profit': 620000,
  },
});

final _expenses = ExpensesBreakdownDto.fromJson(const {
  'total': 330000,
  'by_category': {'wage': 250000, 'electricity': 80000},
  'by_branch': [
    {
      'branch_id': 1,
      'total': 200000,
      'by_category': {'wage': 150000, 'electricity': 50000},
    },
  ],
});

void main() {
  late _MockBehavior behavior;
  late GetObjectsFinanceUseCase useCase;

  setUp(() {
    behavior = _MockBehavior();
    useCase = GetObjectsFinanceUseCase(behavior);
  });

  void stub({BranchDashboard? branches, ExpensesBreakdown? expenses}) {
    when(() => behavior.getBranches(
          period: any(named: 'period'),
          date: any(named: 'date'),
        )).thenAnswer((_) async => branches);
    when(() => behavior.getExpenses(
          period: any(named: 'period'),
          date: any(named: 'date'),
        )).thenAnswer((_) async => expenses);
  }

  group('GetObjectsFinanceUseCase merge', () {
    test('All aggregate uses top-level by_category; per-branch fallback netProfit',
        () async {
      stub(branches: _branches, expenses: _expenses);
      final r = await useCase(period: 'week', date: '2026-06-13');
      expect(r, isNotNull);
      expect(r!.objects, hasLength(3)); // All + 2

      final all = r.objects.firstWhere((o) => o.isAll);
      expect(all.expensesByCategory['wage'], 250000); // полная разбивка
      expect(all.unallocatedOpex, 80000);
      expect(all.netProfit, 620000);

      final c2 = r.objects.firstWhere((o) => o.id == 2);
      // нет opex_total/net_profit/by_branch → expensesTotal 0, netProfit=rev-cost
      expect(c2.expensesTotal, 0);
      expect(c2.netProfit, 250000);
    });

    test('null branches → null result (failure)', () async {
      stub(branches: null, expenses: _expenses);
      expect(await useCase(period: 'week', date: '2026-06-13'), isNull);
    });
  });

  group('BranchesBloc', () {
    blocTest<BranchesBloc, BranchesState>(
      'Requested → [loading, success]',
      setUp: () => stub(branches: _branches, expenses: _expenses),
      build: () => BranchesBloc(useCase),
      act: (b) => b.add(const BranchesRequested()),
      expect: () => [
        isA<BranchesState>()
            .having((s) => s.status, 'status', BranchesStatus.loading),
        isA<BranchesState>()
            .having((s) => s.status, 'status', BranchesStatus.success)
            .having((s) => s.objects.length, 'objects', 3),
      ],
    );

    blocTest<BranchesBloc, BranchesState>(
      'BranchSelected filters visible without reload',
      setUp: () => stub(branches: _branches, expenses: _expenses),
      build: () => BranchesBloc(useCase),
      act: (b) async {
        b.add(const BranchesRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const BranchSelected(1));
      },
      skip: 2, // пропускаем loading + первый success
      expect: () => [
        isA<BranchesState>()
            .having((s) => s.selectedId, 'selectedId', 1)
            .having((s) => s.visible.single.id, 'visible', 1),
      ],
    );
  });
}

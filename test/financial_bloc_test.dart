import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/financial/data/dtos/financial_dashboard_dto.dart';
import 'package:mezzome/features/financial/domain/behaviors/financial_behavior.dart';
import 'package:mezzome/features/financial/domain/use_cases/get_financial_dashboard_use_case.dart';
import 'package:mezzome/features/financial/presentation/blocs/financial_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockBehavior extends Mock implements FinancialBehavior {}

final _sample = FinancialDashboardDto.fromJson(const {
  'permissions': {'can_view_money': true},
  'financial': {
    'currency': 'KZT',
    'sales': {'recognized_revenue': '8800.00', 'completed_orders': 2},
    'profitability': {'gross_profit': 4950, 'operating_profit': -6507870},
    'costs': {'cogs': 3850, 'food_cost_pct': 43.75},
    'expense_categories': [
      {'category': 'rent', 'amount': 2500000, 'share_pct': 38.9},
    ],
    'top_items': [
      {'name': 'плов', 'quantity': 3, 'revenue': 8250},
    ],
  },
});

void main() {
  late _MockBehavior behavior;
  late GetFinancialDashboardUseCase useCase;

  setUp(() {
    behavior = _MockBehavior();
    useCase = GetFinancialDashboardUseCase(behavior);
  });

  group('FinancialDashboardDto', () {
    test('parses nested financial object, decimal strings', () {
      expect(_sample.currency, 'KZT');
      expect(_sample.sales.recognizedRevenue, 8800);
      expect(_sample.sales.completedOrders, 2);
      expect(_sample.profitability.operatingProfit, -6507870);
      expect(_sample.costs.foodCostPct, 43.75);
      expect(_sample.expenseCategories.single.category, 'rent');
      expect(_sample.topItems.single.name, 'плов');
      expect(_sample.canViewMoney, isTrue);
    });
  });

  group('FinancialBloc', () {
    blocTest<FinancialBloc, FinancialState>(
      'Requested → [loading, success]',
      setUp: () => when(() => behavior.getFinancial(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => _sample),
      build: () => FinancialBloc(useCase),
      act: (b) => b.add(const FinancialRequested()),
      expect: () => [
        isA<FinancialState>()
            .having((s) => s.status, 'status', FinancialStatus.loading),
        isA<FinancialState>()
            .having((s) => s.status, 'status', FinancialStatus.success)
            .having((s) => s.data, 'data', isNotNull),
      ],
    );

    blocTest<FinancialBloc, FinancialState>(
      'error → [loading, failure] with message',
      setUp: () => when(() => behavior.getFinancial(
            period: any(named: 'period'),
            date: any(named: 'date'),
          )).thenThrow(Exception('boom')),
      build: () => FinancialBloc(useCase),
      act: (b) => b.add(const FinancialRequested()),
      expect: () => [
        isA<FinancialState>()
            .having((s) => s.status, 'status', FinancialStatus.loading),
        isA<FinancialState>()
            .having((s) => s.status, 'status', FinancialStatus.failure)
            .having((s) => s.error, 'error', contains('boom')),
      ],
    );
  });
}

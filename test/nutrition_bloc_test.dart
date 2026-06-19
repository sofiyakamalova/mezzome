import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/nutrition/data/dtos/nutrition_dashboard_dto.dart';
import 'package:mezzome/features/nutrition/domain/behaviors/nutrition_behavior.dart';
import 'package:mezzome/features/nutrition/domain/use_cases/get_nutrition_use_case.dart';
import 'package:mezzome/features/nutrition/presentation/blocs/nutrition_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockBehavior extends Mock implements NutritionBehavior {}

final _sample = NutritionDashboardDto.fromJson(const {
  'from': '2026-06-01',
  'to': '2026-06-15',
  'permissions': {'can_view_money': true},
  'summary': {'total_cost': 6654487.2, 'average_cost_per_meal': 1185.34},
  'meal_periods': [
    {'code': 'BREAKFAST', 'total_cost': 1386106.8, 'share_pct': 20.83},
    {'code': 'DINNER', 'total_cost': 2524036.4, 'status': 'warning'},
  ],
  'daily': [
    {
      'date': '2026-06-08',
      'total_cost': 562815.6,
      'deviation_pct': 11.2,
      'status': 'warning',
      'composition': {'meat_fish': 68},
    },
  ],
  'composition': [
    {'food_group': 'meat_fish', 'actual_pct': 35.12, 'target_pct': 32},
  ],
  'forecast': {'projected_cost': 14441814.23, 'confidence_pct': 98},
  'insights': [
    {'source': 'analyst', 'title': 'Прогноз', 'message': '...'},
  ],
});

void main() {
  late _MockBehavior behavior;
  late GetNutritionUseCase useCase;

  setUp(() {
    behavior = _MockBehavior();
    useCase = GetNutritionUseCase(behavior);
  });

  void stub(dynamic value) => when(
        () => behavior.getNutrition(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => value);

  group('NutritionDashboardDto', () {
    test('parses summary, meals, composition, forecast', () {
      expect(_sample.summary.totalCost, 6654487.2);
      expect(_sample.mealByCode('breakfast')?.sharePct, 20.83);
      expect(_sample.daily.single.composition['meat_fish'], 68);
      expect(_sample.composition.single.targetPct, 32);
      expect(_sample.forecast?.projectedCost, 14441814.23);
    });
  });

  group('GetNutritionUseCase range', () {
    test('day → from==to; passes range to behavior', () async {
      stub(_sample);
      await useCase(period: 'day', date: DateTime(2026, 6, 8));
      verify(() => behavior.getNutrition(from: '2026-06-08', to: '2026-06-08'))
          .called(1);
    });

    test('month → first..last day of month', () async {
      stub(_sample);
      await useCase(period: 'month', date: DateTime(2026, 6, 14));
      verify(() => behavior.getNutrition(from: '2026-06-01', to: '2026-06-30'))
          .called(1);
    });
  });

  group('NutritionBloc', () {
    blocTest<NutritionBloc, NutritionState>(
      'Requested → [loading, success]',
      setUp: () => stub(_sample),
      build: () => NutritionBloc(useCase),
      act: (b) => b.add(const NutritionRequested()),
      expect: () => [
        isA<NutritionState>()
            .having((s) => s.status, 'status', NutritionStatus.loading),
        isA<NutritionState>()
            .having((s) => s.status, 'status', NutritionStatus.success)
            .having((s) => s.data, 'data', isNotNull),
      ],
    );

    blocTest<NutritionBloc, NutritionState>(
      'null → [loading, failure] (best-effort)',
      setUp: () => stub(null),
      build: () => NutritionBloc(useCase),
      act: (b) => b.add(const NutritionRequested()),
      expect: () => [
        isA<NutritionState>()
            .having((s) => s.status, 'status', NutritionStatus.loading),
        isA<NutritionState>()
            .having((s) => s.status, 'status', NutritionStatus.failure),
      ],
    );
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/domain/behaviors/production_grid_behavior.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';
import 'package:mezzome/features/dishes/domain/models/production_grid.dart';
import 'package:mezzome/features/dishes/domain/use_cases/get_production_grid_use_case.dart';
import 'package:mezzome/features/dishes/presentation/blocs/production_grid_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'test_helpers.dart';

class _MockBehavior extends Mock implements ProductionGridBehavior {}

void main() {
  setUpAll(() async {
    await setupLocalizationTests(); // .tr() в сообщениях об ошибках
    registerFallbackValue(UserRole.chef); // для any(named:'role')
  });

  late _MockBehavior behavior;
  GetProductionGridUseCase useCase() => GetProductionGridUseCase(behavior);

  setUp(() => behavior = _MockBehavior());

  const grid = ProductionPlanGridResponse(serviceTypeTitle: 'Завтрак');

  void stubOk() => when(() => behavior.getGrid(
        role: any(named: 'role'),
        weekStart: any(named: 'weekStart'),
        serviceType: any(named: 'serviceType'),
        kitchenId: any(named: 'kitchenId'),
      )).thenAnswer((_) async => grid);

  blocTest<ProductionGridBloc, ProductionGridState>(
    'chef + load → [loading, success]',
    setUp: stubOk,
    build: () =>
        ProductionGridBloc(getGrid: useCase(), role: UserRole.chef),
    act: (b) => b.add(const GridLoadRequested()),
    expect: () => [
      isA<ProductionGridState>().having((s) => s.isLoading, 'loading', true),
      isA<ProductionGridState>()
          .having((s) => s.isLoading, 'loading', false)
          .having((s) => s.grid, 'grid', isNotNull),
    ],
  );

  blocTest<ProductionGridBloc, ProductionGridState>(
    'role without grid endpoint → forbidden message, no network',
    build: () => ProductionGridBloc(getGrid: useCase(), role: null),
    act: (b) => b.add(const GridLoadRequested()),
    expect: () => [
      isA<ProductionGridState>()
          .having((s) => s.errorMessage, 'error', isNotNull)
          .having((s) => s.isLoading, 'loading', false),
    ],
    verify: (_) => verifyNever(() => behavior.getGrid(
          role: any(named: 'role'),
          weekStart: any(named: 'weekStart'),
          serviceType: any(named: 'serviceType'),
          kitchenId: any(named: 'kitchenId'),
        )),
  );

  blocTest<ProductionGridBloc, ProductionGridState>(
    'service change reloads with new service',
    setUp: stubOk,
    build: () =>
        ProductionGridBloc(getGrid: useCase(), role: UserRole.manager),
    act: (b) => b.add(const GridServiceSelected(MenuServiceType.lunch)),
    expect: () => [
      isA<ProductionGridState>()
          .having((s) => s.service, 'service', MenuServiceType.lunch)
          .having((s) => s.isRefreshing, 'refreshing', true),
      isA<ProductionGridState>()
          .having((s) => s.isRefreshing, 'refreshing', false)
          .having((s) => s.grid, 'grid', isNotNull),
    ],
    verify: (_) => verify(() => behavior.getGrid(
          role: UserRole.manager,
          weekStart: any(named: 'weekStart'),
          serviceType: MenuServiceType.lunch.apiValue,
          kitchenId: any(named: 'kitchenId'),
        )).called(1),
  );
}

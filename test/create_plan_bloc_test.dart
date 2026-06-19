import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dishes/data/models/dish_model.dart';
import 'package:mezzome/features/dishes/data/models/menu_category_model.dart';
import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';
import 'package:mezzome/features/dishes/domain/behaviors/create_plan_behavior.dart';
import 'package:mezzome/features/dishes/domain/use_cases/create_production_plan_use_case.dart';
import 'package:mezzome/features/dishes/domain/use_cases/load_plan_form_use_case.dart';
import 'package:mezzome/features/dishes/presentation/blocs/create_plan_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockBehavior extends Mock implements CreatePlanBehavior {}

class _FakeRequest extends Fake implements ProductionPlanCreateRequest {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeRequest()));

  late _MockBehavior behavior;

  CreatePlanBloc build() => CreatePlanBloc(
        role: UserRole.manager,
        loadForm: LoadPlanFormUseCase(behavior),
        createPlan: CreateProductionPlanUseCase(behavior),
      );

  void stubBootstrap() {
    when(() => behavior.planKitchens(any()))
        .thenAnswer((_) async => const [KitchenModel(id: 1, name: 'K1')]);
    when(() => behavior.fetchCatalogDishes(any())).thenAnswer(
        (_) async => const [DishModel(id: 10, name: 'Плов', categoryId: 5)]);
    when(() => behavior.fetchMenuCategories()).thenAnswer((_) async =>
        const [MenuCategoryModel(id: 5, name: 'Основное', sortOrder: 1)]);
  }

  setUp(() {
    behavior = _MockBehavior();
    stubBootstrap();
  });

  blocTest<CreatePlanBloc, CreatePlanState>(
    'bootstrap loads kitchens/catalog/categories and preselects kitchen',
    build: build,
    // конструктор сам шлёт CreatePlanStarted
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.isBootstrapping, isFalse);
      expect(bloc.state.kitchenId, 1);
      expect(bloc.state.catalog, hasLength(1));
      expect(bloc.state.categories, hasLength(1));
    },
  );

  blocTest<CreatePlanBloc, CreatePlanState>(
    'submit success → createdPlan set, builds slot from category',
    setUp: () => when(() => behavior.createPlan(any(), any()))
        .thenAnswer((_) async => const ProductionPlanDetail(id: 77)),
    build: build,
    act: (b) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const PlanItemDishChanged(0, 10));
      b.add(const PlanItemPortionsChanged(0, 50));
      b.add(const PlanSubmitted());
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.createdPlan?.id, 77);
      final captured =
          verify(() => behavior.createPlan(any(), captureAny())).captured.last
              as ProductionPlanCreateRequest;
      expect(captured.items.single.slotKey, 'category_5');
      expect(captured.items.single.plannedPortions, 50);
    },
  );

  blocTest<CreatePlanBloc, CreatePlanState>(
    'submit validation error → submitError + fieldErrors',
    setUp: () => when(() => behavior.createPlan(any(), any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 400,
          data: const {
            'details': 'bad',
            'validation': {'items': 'required'},
          },
        ),
      ),
    ),
    build: build,
    act: (b) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const PlanItemDishChanged(0, 10));
      b.add(const PlanItemPortionsChanged(0, 50));
      b.add(const PlanSubmitted());
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.submitError, isNotNull);
      expect(bloc.state.fieldErrors['items'], 'required');
      expect(bloc.state.createdPlan, isNull);
    },
  );
}

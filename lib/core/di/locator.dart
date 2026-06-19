import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mezzome/core/di/session_holder.dart';
import 'package:mezzome/core/network/app_dio.dart';
import 'package:mezzome/core/router/app_router.dart';
import 'package:mezzome/core/services/device_info_service.dart';
import 'package:mezzome/core/services/token_refresh_service.dart';
import 'package:mezzome/core/services/token_storage.dart';
import 'package:mezzome/core/theme/theme_mode_cubit.dart';
import 'package:mezzome/features/auth/data/api/auth_api.dart';
import 'package:mezzome/features/auth/data/repository/auth_repository.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';
import 'package:mezzome/features/auth/data/services/auth_service.dart';
import 'package:mezzome/features/auth/domain/behaviors/auth_behavior.dart';
import 'package:mezzome/features/auth/domain/use_cases/send_login_otp_use_case.dart';
import 'package:mezzome/features/auth/domain/use_cases/verify_login_otp_use_case.dart';
import 'package:mezzome/features/auth/presentation/blocs/login_bloc.dart';
import 'package:mezzome/features/approvals/data/services/approvals_service.dart';
import 'package:mezzome/features/approvals/data/services/my_requests_service.dart';
import 'package:mezzome/features/approvals/data/sources/approvals_remote_source.dart';
import 'package:mezzome/features/approvals/data/sources/my_requests_remote_source.dart';
import 'package:mezzome/features/approvals/domain/behaviors/approvals_behavior.dart';
import 'package:mezzome/features/approvals/domain/behaviors/my_requests_behavior.dart';
import 'package:mezzome/features/approvals/domain/use_cases/decide_approval_use_case.dart';
import 'package:mezzome/features/approvals/domain/use_cases/load_approvals_queue_use_case.dart';
import 'package:mezzome/features/approvals/domain/use_cases/load_my_requests_use_case.dart';
import 'package:mezzome/features/approvals/presentation/blocs/approvals_bloc.dart';
import 'package:mezzome/features/approvals/presentation/blocs/my_requests_bloc.dart';
import 'package:mezzome/features/branches/data/services/branches_service.dart';
import 'package:mezzome/features/branches/data/sources/branches_remote_source.dart';
import 'package:mezzome/features/branches/domain/behaviors/branches_behavior.dart';
import 'package:mezzome/features/branches/domain/use_cases/get_objects_finance_use_case.dart';
import 'package:mezzome/features/branches/presentation/blocs/branches_bloc.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/dashboard/data/api/dashboard_api.dart';
import 'package:mezzome/features/dashboard/data/repository/dashboard_repository.dart';
import 'package:mezzome/features/dashboard/data/services/manager_dashboard_service.dart';
import 'package:mezzome/features/dashboard/domain/behaviors/manager_dashboard_behavior.dart';
import 'package:mezzome/features/dashboard/domain/use_cases/load_manager_dashboard_use_case.dart';
import 'package:mezzome/features/dashboard/presentation/blocs/dashboard_bloc.dart';
import 'package:mezzome/features/dishes/data/api/dishes_api.dart';
import 'package:mezzome/features/dishes/data/api/ingredients_api.dart';
import 'package:mezzome/features/dishes/data/api/production_plans_api.dart';
import 'package:mezzome/features/dishes/data/api/technical_cards_api.dart';
import 'package:mezzome/features/dishes/data/repository/dishes_repository.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';
import 'package:mezzome/features/dishes/data/services/create_plan_service.dart';
import 'package:mezzome/features/dishes/data/services/production_grid_service.dart';
import 'package:mezzome/features/dishes/data/sources/create_plan_remote_source.dart';
import 'package:mezzome/features/dishes/data/sources/production_grid_remote_source.dart';
import 'package:mezzome/features/dishes/domain/behaviors/create_plan_behavior.dart';
import 'package:mezzome/features/dishes/domain/behaviors/production_grid_behavior.dart';
import 'package:mezzome/features/dishes/domain/use_cases/create_production_plan_use_case.dart';
import 'package:mezzome/features/dishes/domain/use_cases/get_production_grid_use_case.dart';
import 'package:mezzome/features/dishes/domain/use_cases/load_plan_form_use_case.dart';
import 'package:mezzome/features/dishes/presentation/blocs/create_plan_bloc.dart';
import 'package:mezzome/features/dishes/presentation/blocs/menu_dashboard_cubit.dart';
import 'package:mezzome/features/dishes/presentation/blocs/production_grid_bloc.dart';
import 'package:mezzome/features/dishes/presentation/blocs/tech_card_cubit.dart';
import 'package:mezzome/features/financial/data/services/financial_service.dart';
import 'package:mezzome/features/financial/data/sources/financial_remote_source.dart';
import 'package:mezzome/features/financial/domain/behaviors/financial_behavior.dart';
import 'package:mezzome/features/financial/domain/use_cases/get_financial_dashboard_use_case.dart';
import 'package:mezzome/features/financial/presentation/blocs/financial_bloc.dart';
import 'package:mezzome/features/nutrition/data/services/nutrition_service.dart';
import 'package:mezzome/features/nutrition/data/sources/nutrition_remote_source.dart';
import 'package:mezzome/features/nutrition/domain/behaviors/nutrition_behavior.dart';
import 'package:mezzome/features/nutrition/domain/use_cases/get_nutrition_use_case.dart';
import 'package:mezzome/features/nutrition/presentation/blocs/nutrition_bloc.dart';
import 'package:mezzome/features/warehouse/data/services/warehouse_service.dart';
import 'package:mezzome/features/warehouse/data/sources/warehouse_remote_source.dart';
import 'package:mezzome/features/warehouse/domain/behaviors/warehouse_behavior.dart';
import 'package:mezzome/features/warehouse/domain/use_cases/get_warehouse_dashboard_use_case.dart';
import 'package:mezzome/features/warehouse/presentation/blocs/warehouse_bloc.dart';

/// Сервис-локатор (get_it). DI для фич на BLoC. Riverpod ещё используется
/// остальными фичами — оба контейнера сосуществуют в переходный период.
final sl = GetIt.instance;

Future<void> configureDependencies() async {
  _registerCore();
  _registerAuth();
  _registerSession();
  _registerDishesShared();
  _registerWarehouse();
  _registerBranches();
  _registerNutrition();
  _registerFinancial();
  _registerProductionGrid();
  _registerCreatePlan();
  _registerMenuDashboard();
  _registerManagerDashboard();
  _registerApprovals();
}

/// Очередь согласования техкарт: source(Dio) → service(behavior) → use_cases → bloc.
void _registerApprovals() {
  sl.registerLazySingleton(() => ApprovalsRemoteSource(sl<Dio>()));
  sl.registerLazySingleton<ApprovalsBehavior>(
    () => ApprovalsService(sl<ApprovalsRemoteSource>()),
  );
  sl.registerLazySingleton(
    () => LoadApprovalsQueueUseCase(sl<ApprovalsBehavior>()),
  );
  sl.registerLazySingleton(() => DecideApprovalUseCase(sl<ApprovalsBehavior>()));
  sl.registerFactory(
    () => ApprovalsBloc(
      loadQueue: sl<LoadApprovalsQueueUseCase>(),
      decide: sl<DecideApprovalUseCase>(),
    ),
  );

  // «Мои запросы» (роль chef): список техкарт-запросов с серверным фильтром.
  sl.registerLazySingleton(
    () => MyRequestsRemoteSource(sl<TechnicalCardsApi>()),
  );
  sl.registerLazySingleton<MyRequestsBehavior>(
    () => MyRequestsService(sl<MyRequestsRemoteSource>()),
  );
  sl.registerLazySingleton(
    () => LoadMyRequestsUseCase(sl<MyRequestsBehavior>()),
  );
  sl.registerFactory(() => MyRequestsBloc(sl<LoadMyRequestsUseCase>()));
}

/// Вкладка «Дашборд» (manager-reports): DashboardRepository → service(behavior)
/// → use_case → bloc. DashboardRepository также делегируется из Riverpod.
void _registerManagerDashboard() {
  sl.registerLazySingleton(() => DashboardApi(sl<Dio>()));
  sl.registerLazySingleton(() => DashboardRepository(sl<DashboardApi>()));
  sl.registerLazySingleton<ManagerDashboardBehavior>(
    () => ManagerDashboardService(sl<DashboardRepository>()),
  );
  sl.registerLazySingleton(
    () => LoadManagerDashboardUseCase(sl<ManagerDashboardBehavior>()),
  );
  sl.registerFactory(() => DashboardBloc(sl<LoadManagerDashboardUseCase>()));
}

/// Меню-борд + редактор техкарт. Singleton (общий инстанс для dishes и
/// approvals, как прежний глобальный Riverpod-провайдер).
void _registerMenuDashboard() {
  sl.registerLazySingleton(
    () => MenuDashboardCubit(sl<MenuDashboardRepository>(), sl<SessionHolder>()),
  );
  // Страница детали техкарты — новый инстанс на каждый экран.
  sl.registerFactory(() => TechCardCubit(sl<MenuDashboardRepository>()));
}

/// Общий data-слой dishes (API + Ref-free репозитории) в get_it. Riverpod-
/// провайдеры этих типов делегируют сюда. DishesRepository берёт роль из
/// SessionHolder (мост из authSessionProvider).
void _registerDishesShared() {
  sl.registerLazySingleton(() => DishesApi(sl<Dio>()));
  sl.registerLazySingleton(() => ProductionPlansApi(sl<Dio>()));
  sl.registerLazySingleton(() => TechnicalCardsApi(sl<Dio>()));
  sl.registerLazySingleton(() => IngredientsApi(sl<Dio>()));
  sl.registerLazySingleton(
    () => DishesRepository(
      dishesApi: sl<DishesApi>(),
      productionPlansApi: sl<ProductionPlansApi>(),
      session: sl<SessionHolder>(),
    ),
  );
  sl.registerLazySingleton(
    () => MenuDashboardRepository(
      dishesRepository: sl<DishesRepository>(),
      technicalCardsApi: sl<TechnicalCardsApi>(),
      productionPlansApi: sl<ProductionPlansApi>(),
      ingredientsApi: sl<IngredientsApi>(),
    ),
  );
}

/// Базовая инфраструктура: хранилище токенов, обновление, сеть.
void _registerCore() {
  sl.registerLazySingleton<SessionHolder>(SessionHolder.new);
  sl.registerLazySingleton(ThemeModeCubit.new);
  sl.registerLazySingleton<TokenStorage>(TokenStorage.new);
  sl.registerLazySingleton<DeviceInfoService>(DeviceInfoService.new);
  sl.registerLazySingleton<TokenRefreshService>(
    () => TokenRefreshService(
      tokenStorage: sl<TokenStorage>(),
      deviceInfo: sl<DeviceInfoService>(),
    ),
  );
  sl.registerLazySingleton<Dio>(
    () => buildAppDio(
      tokenStorage: sl<TokenStorage>(),
      refreshService: sl<TokenRefreshService>(),
    ),
  );
}

/// Сессия (get_it): AuthSessionCubit + GoRouter, реагирующий на её поток.
/// Регистрируется после auth (нужен AuthRepository).
void _registerSession() {
  sl.registerLazySingleton(
    () => AuthSessionCubit(sl<AuthRepository>(), sl<SessionHolder>()),
  );
  sl.registerLazySingleton<GoRouter>(
    () => buildAppRouter(sl<AuthSessionCubit>()),
  );
}

/// Вход по телефону: AuthRepository (Retrofit+токены) → service(behavior) →
/// use_cases → LoginBloc. Сессию (authSessionProvider) ведёт Riverpod.
void _registerAuth() {
  sl.registerLazySingleton(() => AuthApi(sl<Dio>()));
  sl.registerLazySingleton(
    () => AuthRepository(
      api: sl<AuthApi>(),
      tokenStorage: sl<TokenStorage>(),
      deviceInfo: sl<DeviceInfoService>(),
    ),
  );
  sl.registerLazySingleton<AuthBehavior>(
    () => AuthService(sl<AuthRepository>()),
  );
  sl.registerLazySingleton(() => SendLoginOtpUseCase(sl<AuthBehavior>()));
  sl.registerLazySingleton(() => VerifyLoginOtpUseCase(sl<AuthBehavior>()));
  sl.registerFactory(
    () => LoginBloc(
      sendOtp: sl<SendLoginOtpUseCase>(),
      verifyOtp: sl<VerifyLoginOtpUseCase>(),
    ),
  );
}

/// Создание плана: source(DishesApi+ProductionPlansApi) → service(behavior) →
/// use_cases → bloc (роль параметром из authSessionProvider).
void _registerCreatePlan() {
  sl.registerLazySingleton(
    () => CreatePlanRemoteSource(
      dishesApi: sl<DishesApi>(),
      plansApi: sl<ProductionPlansApi>(),
    ),
  );
  sl.registerLazySingleton<CreatePlanBehavior>(
    () => CreatePlanService(sl<CreatePlanRemoteSource>()),
  );
  sl.registerLazySingleton(() => LoadPlanFormUseCase(sl<CreatePlanBehavior>()));
  sl.registerLazySingleton(
    () => CreateProductionPlanUseCase(sl<CreatePlanBehavior>()),
  );
  sl.registerFactoryParam<CreatePlanBloc, UserRole?, void>(
    (role, _) => CreatePlanBloc(
      role: role,
      loadForm: sl<LoadPlanFormUseCase>(),
      createPlan: sl<CreateProductionPlanUseCase>(),
    ),
  );
}

/// Недельная сетка меню-борда: source(Dio) → service(behavior) → use_case →
/// bloc (роль передаётся параметром при создании из authSessionProvider).
void _registerProductionGrid() {
  sl.registerLazySingleton(() => ProductionGridRemoteSource(sl<Dio>()));
  sl.registerLazySingleton<ProductionGridBehavior>(
    () => ProductionGridService(sl<ProductionGridRemoteSource>()),
  );
  sl.registerLazySingleton(
    () => GetProductionGridUseCase(sl<ProductionGridBehavior>()),
  );
  sl.registerFactoryParam<ProductionGridBloc, UserRole?, void>(
    (role, _) => ProductionGridBloc(
      getGrid: sl<GetProductionGridUseCase>(),
      role: role,
    ),
  );
}

/// Эталонная вертикаль «Склад»: source → service(behavior) → use_case → bloc.
void _registerWarehouse() {
  sl.registerLazySingleton(() => WarehouseRemoteSource(sl<Dio>()));
  sl.registerLazySingleton<WarehouseBehavior>(
    () => WarehouseService(sl<WarehouseRemoteSource>()),
  );
  sl.registerLazySingleton(
    () => GetWarehouseDashboardUseCase(sl<WarehouseBehavior>()),
  );
  // Новый bloc на каждый показ экрана.
  sl.registerFactory(() => WarehouseBloc(sl<GetWarehouseDashboardUseCase>()));
}

/// Вертикаль «Объекты»: source → service(behavior) → use_case(merge) → bloc.
void _registerBranches() {
  sl.registerLazySingleton(() => BranchesRemoteSource(sl<Dio>()));
  sl.registerLazySingleton<BranchesBehavior>(
    () => BranchesService(sl<BranchesRemoteSource>()),
  );
  sl.registerLazySingleton(
    () => GetObjectsFinanceUseCase(sl<BranchesBehavior>()),
  );
  sl.registerFactory(() => BranchesBloc(sl<GetObjectsFinanceUseCase>()));
}

/// Вертикаль «Питание»: source → service(behavior) → use_case → bloc.
void _registerNutrition() {
  sl.registerLazySingleton(() => NutritionRemoteSource(sl<Dio>()));
  sl.registerLazySingleton<NutritionBehavior>(
    () => NutritionService(sl<NutritionRemoteSource>()),
  );
  sl.registerLazySingleton(() => GetNutritionUseCase(sl<NutritionBehavior>()));
  sl.registerFactory(() => NutritionBloc(sl<GetNutritionUseCase>()));
}

/// Вертикаль «Обзор»: source → service(behavior) → use_case → bloc.
void _registerFinancial() {
  sl.registerLazySingleton(() => FinancialRemoteSource(sl<Dio>()));
  sl.registerLazySingleton<FinancialBehavior>(
    () => FinancialService(sl<FinancialRemoteSource>()),
  );
  sl.registerLazySingleton(
    () => GetFinancialDashboardUseCase(sl<FinancialBehavior>()),
  );
  sl.registerFactory(() => FinancialBloc(sl<GetFinancialDashboardUseCase>()));
}

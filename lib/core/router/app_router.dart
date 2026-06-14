import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/core/router/app_routes.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/auth/presentation/screens/login_screen.dart';
import 'package:mezzome/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mezzome/features/approvals/presentation/screens/my_requests_screen.dart';
import 'package:mezzome/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:mezzome/features/dashboard/presentation/screens/financial_dashboard_screen.dart';
import 'package:mezzome/features/dishes/presentation/screens/create_plan_screen.dart';
import 'package:mezzome/features/dishes/presentation/screens/dish_detail_screen.dart';
import 'package:mezzome/features/dishes/presentation/screens/dishes_screen.dart';
import 'package:mezzome/features/settings/presentation/screens/settings_screen.dart';
import 'package:mezzome/features/shell/presentation/screens/main_shell_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authSession = ref.watch(authSessionProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => _redirect(authSession, state),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: AppRoutes.dashboardName,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.settingsName,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dishes,
                name: AppRoutes.dishesName,
                builder: (context, state) => const DishesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.approvals,
                name: AppRoutes.approvalsName,
                builder: (context, state) => const ApprovalsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myRequests,
                name: AppRoutes.myRequestsName,
                builder: (context, state) => const MyRequestsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.createPlan,
                name: AppRoutes.createPlanName,
                builder: (context, state) => const CreatePlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.expenses,
                name: AppRoutes.expensesName,
                builder: (context, state) => const FinancialDashboardScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.dishDetail,
        name: AppRoutes.dishDetailName,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return DishDetailScreen(dishId: id);
        },
      ),
    ],
  );
});

String? _redirect(AsyncValue<UserModel?> authSession, GoRouterState state) {
  final location = state.matchedLocation;
  final onLogin = location == AppRoutes.login;

  if (authSession.isLoading) {
    return onLogin ? null : AppRoutes.login;
  }

  final user = authSession.valueOrNull;
  final isAuthenticated = user != null;

  if (!isAuthenticated) {
    final target = onLogin ? null : AppRoutes.login;
    if (kDebugMode && target != null) {
      appLogger.i('Redirect → $target (unauthenticated)');
    }
    return target;
  }

  if (onLogin) {
    final home = _homeForRole(user.role);
    appLogger.i('Redirect → $home (${user.role.apiValue})');
    return home;
  }

  if (location == AppRoutes.dashboard &&
      !usesDirectorShell(user.role)) {
    appLogger.i('Redirect → ${AppRoutes.dishes} (no dashboard access)');
    return AppRoutes.dishes;
  }

  if (location == AppRoutes.approvals &&
      !usesDirectorShell(user.role)) {
    appLogger.i('Redirect → ${AppRoutes.dishes} (no approvals access)');
    return AppRoutes.dishes;
  }

  if (location == AppRoutes.expenses &&
      !usesDirectorShell(user.role)) {
    appLogger.i('Redirect → ${AppRoutes.dishes} (no expenses access)');
    return AppRoutes.dishes;
  }

  if (location == AppRoutes.myRequests &&
      usesDirectorShell(user.role)) {
    appLogger.i('Redirect → ${AppRoutes.dashboard} (my-requests is chef-only)');
    return AppRoutes.dashboard;
  }

  // Создание производственного плана на неделю — только для роли manager
  // (директор составляет план, chef его исполняет).
  if (location == AppRoutes.createPlan && user.role != UserRole.manager) {
    appLogger.i('Redirect → ${AppRoutes.dishes} (create-plan is manager-only)');
    return AppRoutes.dishes;
  }

  return null;
}

String _homeForRole(UserRole role) {
  if (usesDirectorShell(role)) {
    return AppRoutes.dashboard;
  }
  return AppRoutes.dishes;
}

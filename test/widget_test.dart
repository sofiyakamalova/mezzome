import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/app.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/presentation/providers/dashboard_notifier.dart';
import 'package:mezzome/features/dashboard/presentation/providers/dashboard_state.dart';
import 'package:mezzome/features/dishes/presentation/providers/dishes_notifier.dart';
import 'package:mezzome/features/dishes/presentation/providers/dishes_state.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('opens manager dashboard when manager session exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithLocalization(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            authSessionProvider.overrideWith(_TestAuthSessionNotifier.new),
            dashboardNotifierProvider.overrideWith(_TestDashboardNotifier.new),
            dishesNotifierProvider.overrideWith(_TestDishesNotifier.new),
          ],
          child: const MezzomeApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Дашборд директора'), findsOneWidget);
    expect(find.textContaining('Эскалации шефа'), findsOneWidget);
    expect(find.textContaining('Активные контракты'), findsOneWidget);
  });
}

class _TestAuthSessionNotifier extends AuthSessionNotifier {
  @override
  Future<UserModel?> build() async {
    return const UserModel(
      id: 1,
      name: 'Director',
      phone: '+77001234567',
      role: UserRole.manager,
    );
  }
}

class _TestDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async {
    return const DashboardState(
      data: ManagerDashboardModel(
        activeContracts: 3,
        conditionalPlans: 1,
        openChefEscalations: 2,
        varianceCostImpact: 1500,
      ),
    );
  }
}

class _TestDishesNotifier extends DishesNotifier {
  @override
  Future<DishesState> build() async {
    return DishesState(selectedDate: DateTime(2026, 6, 3));
  }
}

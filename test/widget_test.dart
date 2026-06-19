import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/app.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/di/session_holder.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/presentation/blocs/dashboard_bloc.dart';

import 'test_helpers.dart';

const _managerUser = UserModel(
  id: 1,
  name: 'Director',
  phone: '+77001234567',
  role: UserRole.manager,
);

/// Сессия без сети: всегда авторизованный менеджер.
class _FakeAuthSessionCubit extends Cubit<AuthSessionState>
    implements AuthSessionCubit {
  _FakeAuthSessionCubit()
      : super(const AuthSessionState(AuthStatus.authenticated, _managerUser));

  @override
  Future<void> restore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> logout() async {}
}

class _MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  setUp(() async {
    await sl.reset();
    await configureDependencies();

    // Сессия → менеджер (без сети).
    sl.unregister<AuthSessionCubit>();
    sl.registerLazySingleton<AuthSessionCubit>(_FakeAuthSessionCubit.new);
    sl<SessionHolder>().user = _managerUser;

    // Дашборд → засеянный bloc (без сети).
    sl.unregister<DashboardBloc>();
    sl.registerFactory<DashboardBloc>(() {
      final bloc = _MockDashboardBloc();
      whenListen(
        bloc,
        const Stream<DashboardState>.empty(),
        initialState: const DashboardState(
          status: DashboardStatus.success,
          data: ManagerDashboardModel(
            activeContracts: 3,
            conditionalPlans: 1,
            openChefEscalations: 2,
            varianceCostImpact: 1500,
          ),
        ),
      );
      return bloc;
    });
  });

  tearDown(() async => sl.reset());

  testWidgets('opens manager dashboard when manager session exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithLocalization(
        const MezzomeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Дашборд директора'), findsOneWidget);
    expect(find.textContaining('Эскалации шефа'), findsOneWidget);
    expect(find.textContaining('Активные контракты'), findsOneWidget);
  });
}

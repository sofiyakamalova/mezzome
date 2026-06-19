import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/auth/presentation/blocs/login_bloc.dart';
import 'package:mezzome/features/auth/presentation/screens/login_screen.dart';

import 'test_helpers.dart';

class _MockLoginBloc extends MockBloc<LoginEvent, LoginState>
    implements LoginBloc {}

void main() {
  testWidgets('login screen shows phone and otp steps', (tester) async {
    // Шаг телефона.
    final phoneBloc = _MockLoginBloc();
    whenListen(
      phoneBloc,
      const Stream<LoginState>.empty(),
      initialState: const LoginState(),
    );
    await tester.pumpWidget(wrapMaterialApp(LoginScreen(bloc: phoneBloc)));
    await tester.pumpAndSettle();

    expect(find.text('Вход по номеру телефона'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);

    // Шаг OTP.
    final otpBloc = _MockLoginBloc();
    whenListen(
      otpBloc,
      const Stream<LoginState>.empty(),
      initialState:
          const LoginState(step: LoginStep.otp, phone: '+77001234567'),
    );
    await tester.pumpWidget(wrapMaterialApp(LoginScreen(bloc: otpBloc)));
    await tester.pumpAndSettle();

    expect(find.text('Введите код из SMS'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}

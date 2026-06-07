import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/auth/presentation/providers/login_notifier.dart';
import 'package:mezzome/features/auth/presentation/providers/login_state.dart';
import 'package:mezzome/features/auth/presentation/screens/login_screen.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('login screen shows phone and otp steps', (WidgetTester tester) async {
    await tester.pumpWidget(wrapMaterialApp(const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Вход по номеру телефона'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);

    await tester.pumpWidget(
      wrapMaterialApp(
        const LoginScreen(),
        overrides: [loginNotifierProvider.overrideWith(_FakeLoginNotifier.new)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Введите код из SMS'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}

class _FakeLoginNotifier extends LoginNotifier {
  @override
  LoginState build() {
    return const LoginState(step: LoginStep.otp, phone: '+77001234567');
  }
}

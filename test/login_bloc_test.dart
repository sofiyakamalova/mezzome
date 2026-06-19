import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/auth/domain/behaviors/auth_behavior.dart';
import 'package:mezzome/features/auth/domain/use_cases/send_login_otp_use_case.dart';
import 'package:mezzome/features/auth/domain/use_cases/verify_login_otp_use_case.dart';
import 'package:mezzome/features/auth/presentation/blocs/login_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'test_helpers.dart';

class _MockAuth extends Mock implements AuthBehavior {}

void main() {
  setUpAll(setupLocalizationTests); // для .tr() в сообщениях об ошибках

  late _MockAuth auth;
  LoginBloc build() => LoginBloc(
        sendOtp: SendLoginOtpUseCase(auth),
        verifyOtp: VerifyLoginOtpUseCase(auth),
      );

  setUp(() => auth = _MockAuth());

  const validPhone = '+77001234567';

  blocTest<LoginBloc, LoginState>(
    'invalid phone → error, no network call',
    build: build,
    seed: () => const LoginState(phone: '+7 70'),
    act: (b) => b.add(const LoginOtpRequested()),
    expect: () => [
      isA<LoginState>().having((s) => s.errorMessage, 'error', isNotNull),
    ],
    verify: (_) => verifyNever(() => auth.sendOtpForLogin(any())),
  );

  blocTest<LoginBloc, LoginState>(
    'OtpRequested success → step otp',
    setUp: () =>
        when(() => auth.sendOtpForLogin(any())).thenAnswer((_) async => false),
    build: build,
    seed: () => const LoginState(phone: validPhone),
    act: (b) => b.add(const LoginOtpRequested()),
    expect: () => [
      isA<LoginState>().having((s) => s.isLoading, 'loading', true),
      isA<LoginState>()
          .having((s) => s.isLoading, 'loading', false)
          .having((s) => s.step, 'step', LoginStep.otp),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'Verify success → verified=true',
    setUp: () => when(() => auth.verifyOtp(
          phone: any(named: 'phone'),
          otp: any(named: 'otp'),
        )).thenAnswer((_) async {}),
    build: build,
    seed: () =>
        const LoginState(step: LoginStep.otp, phone: validPhone, otp: '123456'),
    act: (b) => b.add(const LoginVerifySubmitted()),
    expect: () => [
      isA<LoginState>().having((s) => s.isLoading, 'loading', true),
      isA<LoginState>()
          .having((s) => s.isLoading, 'loading', false)
          .having((s) => s.verified, 'verified', true),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'short OTP → error, no verify call',
    build: build,
    seed: () =>
        const LoginState(step: LoginStep.otp, phone: validPhone, otp: '12'),
    act: (b) => b.add(const LoginVerifySubmitted()),
    expect: () => [
      isA<LoginState>().having((s) => s.errorMessage, 'error', isNotNull),
    ],
    verify: (_) => verifyNever(
      () => auth.verifyOtp(phone: any(named: 'phone'), otp: any(named: 'otp')),
    ),
  );
}

import 'package:mezzome/features/auth/domain/behaviors/auth_behavior.dart';

/// Проверить OTP и сохранить сессию.
class VerifyLoginOtpUseCase {
  const VerifyLoginOtpUseCase(this._behavior);

  final AuthBehavior _behavior;

  Future<void> call({required String phone, required String otp}) =>
      _behavior.verifyOtp(phone: phone, otp: otp);
}

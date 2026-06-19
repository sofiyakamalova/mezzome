import 'package:mezzome/features/auth/domain/behaviors/auth_behavior.dart';

/// Отправить OTP для входа. Возвращает флаг dev-fallback регистрации.
class SendLoginOtpUseCase {
  const SendLoginOtpUseCase(this._behavior);

  final AuthBehavior _behavior;

  Future<bool> call(String phone) => _behavior.sendOtpForLogin(phone);
}

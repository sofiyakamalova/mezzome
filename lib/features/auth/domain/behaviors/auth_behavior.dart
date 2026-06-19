/// Контракт входа по телефону (OTP). Реализуется в data/services поверх
/// существующего AuthRepository (токены/профиль). Сессию (текущий юзер) ведёт
/// отдельный authSessionProvider (Riverpod) — мигрируется последним.
abstract class AuthBehavior {
  /// Отправить OTP для входа. Возвращает true, если на dev сработал fallback
  /// регистрации клиента (USER_NOT_FOUND).
  Future<bool> sendOtpForLogin(String phone);

  /// Проверить код и сохранить сессию (токены + профиль).
  Future<void> verifyOtp({required String phone, required String otp});
}

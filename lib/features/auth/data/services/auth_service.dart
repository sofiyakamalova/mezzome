import 'package:mezzome/features/auth/data/repository/auth_repository.dart';
import 'package:mezzome/features/auth/domain/behaviors/auth_behavior.dart';

/// Реализация [AuthBehavior] поверх существующего [AuthRepository]
/// (Retrofit + хранилище токенов). Без дублирования токен-логики.
class AuthService implements AuthBehavior {
  const AuthService(this._repo);

  final AuthRepository _repo;

  @override
  Future<bool> sendOtpForLogin(String phone) => _repo.sendOtpForLogin(phone);

  @override
  Future<void> verifyOtp({required String phone, required String otp}) =>
      _repo.verifyOtp(phone: phone, otp: otp);
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/config/app_config.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/api_client.dart';
import 'package:mezzome/core/services/device_info_provider.dart';
import 'package:mezzome/core/services/device_info_service.dart';
import 'package:mezzome/core/services/token_storage.dart';
import 'package:mezzome/core/services/token_storage_provider.dart';
import 'package:mezzome/features/auth/data/api/auth_api.dart';
import 'package:mezzome/features/auth/data/models/otp_send_request.dart';
import 'package:mezzome/features/auth/data/models/otp_verify_request.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/domain/phone_utils.dart';

class AuthRepository {
  AuthRepository({
    required AuthApi api,
    required TokenStorage tokenStorage,
    required DeviceInfoService deviceInfo,
  })  : _api = api,
        _tokenStorage = tokenStorage,
        _deviceInfo = deviceInfo;

  final AuthApi _api;
  final TokenStorage _tokenStorage;
  final DeviceInfoService _deviceInfo;

  Future<void> sendOtp(
    String phone, {
    String? role,
    int? restaurantId,
  }) async {
    appLogger.i(
      'Sending OTP to ${normalizePhone(phone)}'
      '${role != null ? ' role=$role' : ''}',
    );
    await _api.sendOtp(
      OtpSendRequest(
        phone: normalizePhone(phone),
        role: role,
        restaurantId: restaurantId,
      ),
    );
  }

  /// Staff login: send OTP. In debug, falls back to client registration on dev.
  Future<bool> sendOtpForLogin(String phone) async {
    try {
      await sendOtp(phone);
      return false;
    } on DioException catch (error) {
      if (kDebugMode && _isUserNotFound(error)) {
        appLogger.i('USER_NOT_FOUND, dev client registration fallback');
        await sendOtp(
          phone,
          role: UserRole.client.apiValue,
          restaurantId: AppConfig.devRegistrationRestaurantId,
        );
        return true;
      }
      rethrow;
    }
  }

  Future<UserModel> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final normalizedPhone = normalizePhone(phone);
    final deviceId = await _deviceInfo.getDeviceId();

    final tokens = await _api.verifyOtp(
      OtpVerifyRequest(
        phone: normalizedPhone,
        otp: otp.trim(),
        deviceId: deviceId,
        deviceType: _deviceInfo.deviceType,
        appVersion: _deviceInfo.appVersion,
        deviceName: _deviceInfo.deviceName,
      ),
    );

    await _tokenStorage.saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      phone: normalizedPhone,
    );

    final profile = await _api.getProfile();
    appLogger.i('Signed in: ${profile.name} (${profile.role.apiValue})');
    return profile;
  }

  Future<UserModel?> getCurrentUser() async {
    if (!await _tokenStorage.hasTokens()) {
      return null;
    }
    try {
      return await _api.getProfile();
    } catch (e, st) {
      appLogger.w('Profile load failed, clearing session', error: e, stackTrace: st);
      await _tokenStorage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    appLogger.i('Logout');
    await _tokenStorage.clear();
  }
}

bool _isUserNotFound(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['error'] == 'USER_NOT_FOUND') {
    return true;
  }
  return false;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    deviceInfo: ref.watch(deviceInfoProvider),
  );
});

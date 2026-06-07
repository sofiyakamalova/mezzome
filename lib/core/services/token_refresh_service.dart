import 'package:dio/dio.dart';
import 'package:mezzome/core/config/app_config.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/services/device_info_service.dart';
import 'package:mezzome/core/services/token_storage.dart';
import 'package:mezzome/features/auth/data/models/refresh_token_request.dart';
import 'package:mezzome/features/auth/data/models/refresh_token_response.dart';

/// Refreshes JWT via `POST /public/otp/refresh` (§8 ТЗ: 401 → refresh).
class TokenRefreshService {
  TokenRefreshService({
    required TokenStorage tokenStorage,
    required DeviceInfoService deviceInfo,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _deviceInfo = deviceInfo,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final TokenStorage _tokenStorage;
  final DeviceInfoService _deviceInfo;
  final Dio _dio;

  Future<bool> refreshAccessToken() async {
    final phone = await _tokenStorage.getPhone();
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (phone == null ||
        phone.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      appLogger.w('Refresh skipped: missing phone or refresh token');
      return false;
    }

    appLogger.i('Refreshing access token');
    final deviceId = await _deviceInfo.getDeviceId();

    final response = await _dio.post<Map<String, dynamic>>(
      '/public/otp/refresh',
      data: RefreshTokenRequest(
        phone: phone,
        deviceId: deviceId,
        refreshToken: refreshToken,
      ).toJson(),
    );

    final data = response.data;
    if (data == null) {
      return false;
    }

    final tokens = RefreshTokenResponse.fromJson(data);
    await _tokenStorage.updateAccessToken(tokens.accessToken);
    appLogger.i('Access token refreshed');
    return true;
  }
}

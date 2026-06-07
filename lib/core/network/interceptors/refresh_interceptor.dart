import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/services/token_refresh_service.dart';
import 'package:mezzome/core/services/token_storage.dart';

/// On 401 retries once after refreshing access token (§8 ТЗ).
class RefreshInterceptor extends QueuedInterceptor {
  RefreshInterceptor({
    required TokenStorage tokenStorage,
    required TokenRefreshService refreshService,
    required Dio dio,
  })  : _tokenStorage = tokenStorage,
        _refreshService = refreshService,
        _dio = dio;

  final TokenStorage _tokenStorage;
  final TokenRefreshService _refreshService;
  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    try {
      appLogger.i('401 on ${err.requestOptions.path}, refreshing token');
      final refreshed = await _refreshService.refreshAccessToken();
      if (!refreshed) {
        appLogger.w('Token refresh failed, clearing session');
        await _tokenStorage.clear();
        handler.next(err);
        return;
      }

      appLogger.i('Token refreshed, retrying ${err.requestOptions.path}');
      final accessToken = await _tokenStorage.getAccessToken();
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer $accessToken';
      options.extra['retried'] = true;

      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (e, st) {
      appLogger.e('Token refresh error', error: e, stackTrace: st);
      await _tokenStorage.clear();
      handler.next(err);
    }
  }

  bool _shouldAttemptRefresh(DioException err) {
    if (err.response?.statusCode != 401) {
      return false;
    }

    final path = err.requestOptions.path;
    if (path.contains('/public/otp/')) {
      return false;
    }

    return err.requestOptions.extra['retried'] != true;
  }
}

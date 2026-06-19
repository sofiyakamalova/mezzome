import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mezzome/core/config/app_config.dart';
import 'package:mezzome/core/logging/dio_logger_interceptor.dart';
import 'package:mezzome/core/network/interceptors/auth_interceptor.dart';
import 'package:mezzome/core/network/interceptors/refresh_interceptor.dart';
import 'package:mezzome/core/services/token_refresh_service.dart';
import 'package:mezzome/core/services/token_storage.dart';

/// Сборка единого `Dio` с интерсепторами. Чистая функция без Riverpod —
/// используется и Riverpod-провайдером ([dioProvider]), и get_it-локатором,
/// чтобы конфигурация сети не дублировалась в переходный период.
Dio buildAppDio({
  required TokenStorage tokenStorage,
  required TokenRefreshService refreshService,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(tokenStorage),
    RefreshInterceptor(
      tokenStorage: tokenStorage,
      refreshService: refreshService,
      dio: dio,
    ),
    if (kDebugMode) DioLoggerInterceptor(),
  ]);

  return dio;
}

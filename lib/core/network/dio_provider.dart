import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/config/app_config.dart';
import 'package:mezzome/core/logging/dio_logger_interceptor.dart';
import 'package:mezzome/core/network/interceptors/auth_interceptor.dart';
import 'package:mezzome/core/network/interceptors/refresh_interceptor.dart';
import 'package:mezzome/core/services/token_refresh_provider.dart';
import 'package:mezzome/core/services/token_storage_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final refreshService = ref.watch(tokenRefreshServiceProvider);

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

  ref.onDispose(dio.close);

  return dio;
});

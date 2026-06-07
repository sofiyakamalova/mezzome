import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/network/dio_provider.dart';
import 'package:mezzome/features/auth/data/api/auth_api.dart';
import 'package:mezzome/features/dashboard/data/api/dashboard_api.dart';

/// Factory for Retrofit API clients sharing one [Dio] instance.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  AuthApi get auth => AuthApi(_dio);

  DashboardApi get dashboard => DashboardApi(_dio);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

final authApiProvider = Provider<AuthApi>((ref) {
  return ref.watch(apiClientProvider).auth;
});

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  return ref.watch(apiClientProvider).dashboard;
});

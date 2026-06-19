import 'package:dio/dio.dart';
import 'package:mezzome/features/financial/data/dtos/financial_dashboard_dto.dart';
import 'package:mezzome/features/financial/domain/models/financial_dashboard.dart';

/// Сырой доступ к главному дашборду (`GET /dashboard`).
class FinancialRemoteSource {
  const FinancialRemoteSource(this._dio);

  final Dio _dio;

  Future<FinancialDashboard> getFinancial({
    required String period,
    required String date,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboard',
      queryParameters: {'period': period, 'date': date},
    );
    return FinancialDashboardDto.fromJson(res.data ?? const {});
  }
}

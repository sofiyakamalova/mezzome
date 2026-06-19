import 'package:dio/dio.dart';
import 'package:mezzome/features/branches/data/dtos/branch_dashboard_dto.dart';
import 'package:mezzome/features/branches/data/dtos/expenses_breakdown_dto.dart';
import 'package:mezzome/features/branches/domain/models/branch_dashboard.dart';
import 'package:mezzome/features/branches/domain/models/expenses_breakdown.dart';

/// Сырой доступ к API объектов (Dio). Ошибки обрабатывает service.
class BranchesRemoteSource {
  const BranchesRemoteSource(this._dio);

  final Dio _dio;

  Future<BranchDashboard> getBranches({
    required String period,
    required String date,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboard/branches',
      queryParameters: {'period': period, 'date': date},
    );
    return BranchDashboardDto.fromJson(res.data ?? const {});
  }

  Future<ExpensesBreakdown> getExpenses({
    required String period,
    required String date,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboard/expenses',
      queryParameters: {'period': period, 'date': date},
    );
    return ExpensesBreakdownDto.fromJson(res.data ?? const {});
  }
}

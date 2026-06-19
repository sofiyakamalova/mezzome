import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/branches/data/sources/branches_remote_source.dart';
import 'package:mezzome/features/branches/domain/behaviors/branches_behavior.dart';
import 'package:mezzome/features/branches/domain/models/branch_dashboard.dart';
import 'package:mezzome/features/branches/domain/models/expenses_breakdown.dart';

/// Реализация [BranchesBehavior]: source + обработка ошибок (best-effort → null).
class BranchesService implements BranchesBehavior {
  const BranchesService(this._source);

  final BranchesRemoteSource _source;

  @override
  Future<BranchDashboard?> getBranches({
    required String period,
    required String date,
  }) =>
      _guard(() => _source.getBranches(period: period, date: date), 'branches');

  @override
  Future<ExpensesBreakdown?> getExpenses({
    required String period,
    required String date,
  }) =>
      _guard(() => _source.getExpenses(period: period, date: date), 'expenses');

  Future<T?> _guard<T>(Future<T> Function() run, String label) async {
    try {
      return await run();
    } on DioException catch (e) {
      appLogger.w('Branches "$label" failed: ${e.message}');
      return null;
    } catch (e) {
      appLogger.w('Branches "$label" failed: $e');
      return null;
    }
  }
}

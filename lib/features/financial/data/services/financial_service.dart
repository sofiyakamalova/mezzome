import 'package:mezzome/features/financial/data/sources/financial_remote_source.dart';
import 'package:mezzome/features/financial/domain/behaviors/financial_behavior.dart';
import 'package:mezzome/features/financial/domain/models/financial_dashboard.dart';

/// Реализация [FinancialBehavior]. «Обзор» обязателен (ошибка = ошибка экрана),
/// поэтому исключения не глотаем — их обработает bloc (→ failure).
class FinancialService implements FinancialBehavior {
  const FinancialService(this._source);

  final FinancialRemoteSource _source;

  @override
  Future<FinancialDashboard> getFinancial({
    required String period,
    required String date,
  }) =>
      _source.getFinancial(period: period, date: date);
}

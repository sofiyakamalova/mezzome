part of 'financial_bloc.dart';

enum FinancialStatus { initial, loading, success, failure }

class FinancialState extends Equatable {
  const FinancialState({
    this.status = FinancialStatus.initial,
    this.data,
    this.period = 'week',
    this.error,
  });

  final FinancialStatus status;
  final FinancialDashboard? data;
  final String period;
  final String? error;

  bool get isLoading => status == FinancialStatus.loading;

  FinancialState copyWith({
    FinancialStatus? status,
    FinancialDashboard? data,
    String? period,
    String? error,
  }) {
    return FinancialState(
      status: status ?? this.status,
      data: data ?? this.data,
      period: period ?? this.period,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, data, period, error];
}

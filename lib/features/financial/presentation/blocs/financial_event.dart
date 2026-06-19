part of 'financial_bloc.dart';

sealed class FinancialEvent extends Equatable {
  const FinancialEvent();

  @override
  List<Object?> get props => [];
}

class FinancialRequested extends FinancialEvent {
  const FinancialRequested();
}

class FinancialRefreshed extends FinancialEvent {
  const FinancialRefreshed();
}

class FinancialPeriodChanged extends FinancialEvent {
  const FinancialPeriodChanged(this.period);

  final String period;

  @override
  List<Object?> get props => [period];
}

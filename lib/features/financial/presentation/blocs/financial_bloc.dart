import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/financial/domain/models/financial_dashboard.dart';
import 'package:mezzome/features/financial/domain/use_cases/get_financial_dashboard_use_case.dart';

part 'financial_event.dart';
part 'financial_state.dart';

/// BLoC сегмента «Обзор» (главный P&L). Зависит только от domain (use_case).
class FinancialBloc extends Bloc<FinancialEvent, FinancialState> {
  FinancialBloc(this._getFinancial) : super(const FinancialState()) {
    on<FinancialRequested>((e, emit) => _load(emit));
    on<FinancialRefreshed>((e, emit) => _load(emit));
    on<FinancialPeriodChanged>((e, emit) {
      emit(state.copyWith(period: e.period));
      return _load(emit);
    });
  }

  final GetFinancialDashboardUseCase _getFinancial;
  final String _date = DateFormatUtil.apiDate(DateFormatUtil.today);

  Future<void> _load(Emitter<FinancialState> emit) async {
    emit(state.copyWith(status: FinancialStatus.loading));
    try {
      final data = await _getFinancial(period: state.period, date: _date);
      emit(state.copyWith(status: FinancialStatus.success, data: data));
    } catch (e) {
      emit(state.copyWith(
        status: FinancialStatus.failure,
        error: e.toString(),
      ));
    }
  }
}

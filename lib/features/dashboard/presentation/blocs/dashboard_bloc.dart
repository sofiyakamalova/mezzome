import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/features/dashboard/data/models/manager_dashboard_model.dart';
import 'package:mezzome/features/dashboard/data/models/manager_reports_model.dart';
import 'package:mezzome/features/dashboard/domain/use_cases/load_manager_dashboard_use_case.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// BLoC вкладки «Дашборд» (manager-reports). Зависит только от domain (use_case).
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._load) : super(const DashboardState()) {
    on<DashboardRequested>((e, emit) => _fetch(emit));
    on<DashboardRefreshed>((e, emit) => _fetch(emit, refresh: true));
    on<DashboardPeriodChanged>((e, emit) {
      if (e.period == state.period) return Future.value();
      emit(state.copyWith(period: e.period));
      return _fetch(emit, refresh: true);
    });
  }

  final LoadManagerDashboardUseCase _load;

  Future<void> _fetch(Emitter<DashboardState> emit, {bool refresh = false}) async {
    emit(refresh
        ? state.copyWith(isRefreshing: true)
        : state.copyWith(status: DashboardStatus.loading));
    try {
      final data = await _load(period: state.period);
      emit(state.copyWith(
        status: DashboardStatus.success,
        isRefreshing: false,
        data: data.dashboard,
        planVsFact: data.planVsFact,
        costPerHead: data.costPerHead,
        variance: data.variance,
        compliance: data.compliance,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.failure,
        isRefreshing: false,
        error: e,
      ));
    }
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/nutrition/domain/models/nutrition_dashboard.dart';
import 'package:mezzome/features/nutrition/domain/use_cases/get_nutrition_use_case.dart';

part 'nutrition_event.dart';
part 'nutrition_state.dart';

/// BLoC сегмента «Питание». Зависит только от domain (use_case). Период
/// day/week/month/year; use_case сам считает диапазон from/to. Режим
/// Менеджер/Овнер — UI-состояние, в bloc не хранится.
class NutritionBloc extends Bloc<NutritionEvent, NutritionState> {
  NutritionBloc(this._getNutrition) : super(const NutritionState()) {
    on<NutritionRequested>((e, emit) => _load(emit));
    on<NutritionRefreshed>((e, emit) => _load(emit));
    on<NutritionPeriodChanged>((e, emit) {
      emit(state.copyWith(period: e.period));
      return _load(emit);
    });
  }

  final GetNutritionUseCase _getNutrition;
  final DateTime _date = DateFormatUtil.today;

  Future<void> _load(Emitter<NutritionState> emit) async {
    emit(state.copyWith(status: NutritionStatus.loading));
    try {
      final data = await _getNutrition(period: state.period, date: _date);
      emit(
        state.copyWith(
          status:
              data == null ? NutritionStatus.failure : NutritionStatus.success,
          data: data,
          clearData: data == null,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: NutritionStatus.failure, clearData: true));
    }
  }
}

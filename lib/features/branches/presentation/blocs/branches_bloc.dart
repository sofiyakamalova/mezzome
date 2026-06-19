import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/utils/date_format.dart';
import 'package:mezzome/features/branches/domain/models/object_finance.dart';
import 'package:mezzome/features/branches/domain/use_cases/get_objects_finance_use_case.dart';

part 'branches_event.dart';
part 'branches_state.dart';

/// BLoC сегмента «Объекты». Зависит только от domain (use_case). Выбор объекта
/// (чип) фильтрует локально, без перезапроса.
class BranchesBloc extends Bloc<BranchesEvent, BranchesState> {
  BranchesBloc(this._getObjects) : super(const BranchesState()) {
    on<BranchesRequested>((e, emit) => _load(emit));
    on<BranchesRefreshed>((e, emit) => _load(emit));
    on<BranchesPeriodChanged>((e, emit) {
      emit(state.copyWith(period: e.period));
      return _load(emit);
    });
    on<BranchSelected>((e, emit) {
      emit(state.copyWith(selectedId: e.id, clearSelected: e.id == null));
    });
  }

  final GetObjectsFinanceUseCase _getObjects;
  final String _date = DateFormatUtil.apiDate(DateFormatUtil.today);

  Future<void> _load(Emitter<BranchesState> emit) async {
    emit(state.copyWith(status: BranchesStatus.loading));
    try {
      final result = await _getObjects(period: state.period, date: _date);
      // Сбрасываем выбор, если объект исчез в новом периоде.
      final keepSelected = result != null &&
          state.selectedId != null &&
          result.branchIds.contains(state.selectedId);
      emit(
        state.copyWith(
          status:
              result == null ? BranchesStatus.failure : BranchesStatus.success,
          result: result,
          clearResult: result == null,
          clearSelected: !keepSelected,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: BranchesStatus.failure, clearResult: true));
    }
  }
}

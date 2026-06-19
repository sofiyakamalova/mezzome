import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/approvals/domain/models/my_request_filter.dart';
import 'package:mezzome/features/approvals/domain/use_cases/load_my_requests_use_case.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';

part 'my_requests_event.dart';
part 'my_requests_state.dart';

/// BLoC «Мои запросы на изменение». Фильтрация — на сервере (смена фильтра
/// перезапрашивает список).
class MyRequestsBloc extends Bloc<MyRequestsEvent, MyRequestsState> {
  MyRequestsBloc(this._load) : super(const MyRequestsState()) {
    on<MyRequestsRequested>((e, emit) => _fetch(emit));
    on<MyRequestsRefreshed>((e, emit) => _fetch(emit));
    on<MyRequestsFilterChanged>((e, emit) {
      if (e.filter == state.filter) return Future.value();
      emit(state.copyWith(filter: e.filter));
      return _fetch(emit);
    });
  }

  final LoadMyRequestsUseCase _load;

  Future<void> _fetch(Emitter<MyRequestsState> emit) async {
    emit(state.copyWith(status: MyRequestsStatus.loading, clearError: true));
    try {
      final cards = await _load(filter: state.filter);
      emit(state.copyWith(status: MyRequestsStatus.success, cards: cards));
    } on DioException catch (e) {
      appLogger.w('My requests load failed: ${e.response?.statusCode}');
      emit(state.copyWith(
        status: MyRequestsStatus.failure,
        error: 'HTTP ${e.response?.statusCode}',
      ));
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/network/dio_error_utils.dart';
import 'package:mezzome/features/approvals/domain/models/approval_item.dart';
import 'package:mezzome/features/approvals/domain/use_cases/decide_approval_use_case.dart';
import 'package:mezzome/features/approvals/domain/use_cases/load_approvals_queue_use_case.dart';

part 'approvals_event.dart';
part 'approvals_state.dart';

/// BLoC очереди согласования техкарт. Очередь грузится целиком, фильтрация по
/// вкладкам — клиентом (геттер [ApprovalsState.visible]).
class ApprovalsBloc extends Bloc<ApprovalsEvent, ApprovalsState> {
  ApprovalsBloc({
    required LoadApprovalsQueueUseCase loadQueue,
    required DecideApprovalUseCase decide,
  })  : _loadQueue = loadQueue,
        _decide = decide,
        super(const ApprovalsState()) {
    on<ApprovalsRequested>((e, emit) => _load(emit));
    on<ApprovalsRefreshed>((e, emit) => _load(emit));
    on<ApprovalsFilterChanged>(
      (e, emit) => emit(state.copyWith(filter: e.filter)),
    );
    on<ApprovalsDecided>(_onDecide);
  }

  final LoadApprovalsQueueUseCase _loadQueue;
  final DecideApprovalUseCase _decide;

  Future<void> _load(Emitter<ApprovalsState> emit) async {
    emit(state.copyWith(status: ApprovalsStatus.loading, clearError: true));
    try {
      final items = await _loadQueue();
      emit(state.copyWith(status: ApprovalsStatus.success, items: items));
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      appLogger.w('Approvals load failed (HTTP $code)');
      emit(state.copyWith(
        status: ApprovalsStatus.failure,
        error: code == 403
            ? 'Нет доступа (FORBIDDEN).\nСогласование техкарт доступно '
                'ролям manager / chef / owner.'
            : 'Не удалось загрузить (HTTP $code).',
      ));
    }
  }

  Future<void> _onDecide(
    ApprovalsDecided e,
    Emitter<ApprovalsState> emit,
  ) async {
    try {
      await _decide(id: e.id, approve: e.approve, reason: e.reason);
      emit(state.copyWith(actionMessage: e.approve ? 'Утверждено' : 'Отклонено'));
      await _load(emit);
    } on DioException catch (err) {
      appLogger.w('Decision failed: ${err.response?.data}');
      emit(state.copyWith(
        actionError: apiErrorDetails(err) ??
            'Ошибка: ${err.response?.statusCode}',
      ));
    }
  }
}

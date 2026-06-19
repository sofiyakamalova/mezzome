part of 'approvals_bloc.dart';

enum ApprovalsStatus { loading, success, failure }

class ApprovalsState {
  const ApprovalsState({
    this.status = ApprovalsStatus.loading,
    this.items = const [],
    this.filter = ApprovalFilter.pending,
    this.error,
    this.actionMessage,
    this.actionError,
  });

  final ApprovalsStatus status;

  /// Вся очередь (все статусы); фильтрация — в [visible].
  final List<ApprovalItem> items;
  final ApprovalFilter filter;

  /// Ошибка загрузки очереди (для экрана ошибки).
  final String? error;

  /// Транзиентные сообщения решения (для BlocListener → flushbar).
  final String? actionMessage;
  final String? actionError;

  List<ApprovalItem> get visible =>
      items.where((i) => i.status == filter).toList();

  ApprovalsState copyWith({
    ApprovalsStatus? status,
    List<ApprovalItem>? items,
    ApprovalFilter? filter,
    String? error,
    bool clearError = false,
    String? actionMessage,
    String? actionError,
  }) {
    return ApprovalsState(
      status: status ?? this.status,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
      // actionMessage/actionError не «липнут»: задаются только при событии
      // решения, иначе сбрасываются (one-shot для listener).
      actionMessage: actionMessage,
      actionError: actionError,
    );
  }
}

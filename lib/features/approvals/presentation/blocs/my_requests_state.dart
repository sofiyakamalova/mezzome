part of 'my_requests_bloc.dart';

enum MyRequestsStatus { loading, success, failure }

class MyRequestsState {
  const MyRequestsState({
    this.status = MyRequestsStatus.loading,
    this.cards = const [],
    this.filter = MyRequestFilter.pending,
    this.error,
  });

  final MyRequestsStatus status;
  final List<TechnicalCardModel> cards;
  final MyRequestFilter filter;
  final String? error;

  MyRequestsState copyWith({
    MyRequestsStatus? status,
    List<TechnicalCardModel>? cards,
    MyRequestFilter? filter,
    String? error,
    bool clearError = false,
  }) {
    return MyRequestsState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

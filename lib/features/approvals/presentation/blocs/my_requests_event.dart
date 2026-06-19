part of 'my_requests_bloc.dart';

sealed class MyRequestsEvent {
  const MyRequestsEvent();
}

class MyRequestsRequested extends MyRequestsEvent {
  const MyRequestsRequested();
}

class MyRequestsRefreshed extends MyRequestsEvent {
  const MyRequestsRefreshed();
}

class MyRequestsFilterChanged extends MyRequestsEvent {
  const MyRequestsFilterChanged(this.filter);

  final MyRequestFilter filter;
}

part of 'approvals_bloc.dart';

sealed class ApprovalsEvent {
  const ApprovalsEvent();
}

class ApprovalsRequested extends ApprovalsEvent {
  const ApprovalsRequested();
}

class ApprovalsRefreshed extends ApprovalsEvent {
  const ApprovalsRefreshed();
}

class ApprovalsFilterChanged extends ApprovalsEvent {
  const ApprovalsFilterChanged(this.filter);

  final ApprovalFilter filter;
}

class ApprovalsDecided extends ApprovalsEvent {
  const ApprovalsDecided({
    required this.id,
    required this.approve,
    required this.reason,
  });

  final Object id;
  final bool approve;
  final String reason;
}

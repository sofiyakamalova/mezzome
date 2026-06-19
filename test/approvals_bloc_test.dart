import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/approvals/domain/models/approval_item.dart';
import 'package:mezzome/features/approvals/domain/use_cases/decide_approval_use_case.dart';
import 'package:mezzome/features/approvals/domain/use_cases/load_approvals_queue_use_case.dart';
import 'package:mezzome/features/approvals/presentation/blocs/approvals_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadQueue extends Mock implements LoadApprovalsQueueUseCase {}

class _MockDecide extends Mock implements DecideApprovalUseCase {}

void main() {
  late _MockLoadQueue load;
  late _MockDecide decide;

  const queue = [
    ApprovalItem(id: 1, name: 'A', status: ApprovalFilter.pending),
    ApprovalItem(id: 2, name: 'B', status: ApprovalFilter.approved),
  ];

  ApprovalsBloc build() => ApprovalsBloc(loadQueue: load, decide: decide);

  setUp(() {
    load = _MockLoadQueue();
    decide = _MockDecide();
  });

  blocTest<ApprovalsBloc, ApprovalsState>(
    'Requested → [loading, success] с очередью',
    setUp: () => when(() => load.call()).thenAnswer((_) async => queue),
    build: build,
    act: (b) => b.add(const ApprovalsRequested()),
    expect: () => [
      isA<ApprovalsState>()
          .having((s) => s.status, 'status', ApprovalsStatus.loading),
      isA<ApprovalsState>()
          .having((s) => s.status, 'status', ApprovalsStatus.success)
          .having((s) => s.items.length, 'items', 2)
          .having((s) => s.visible.length, 'visible(pending)', 1),
    ],
  );

  blocTest<ApprovalsBloc, ApprovalsState>(
    'ошибка загрузки → [loading, failure]',
    setUp: () => when(() => load.call()).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/')),
    ),
    build: build,
    act: (b) => b.add(const ApprovalsRequested()),
    expect: () => [
      isA<ApprovalsState>()
          .having((s) => s.status, 'status', ApprovalsStatus.loading),
      isA<ApprovalsState>()
          .having((s) => s.status, 'status', ApprovalsStatus.failure),
    ],
  );

  blocTest<ApprovalsBloc, ApprovalsState>(
    'FilterChanged меняет фильтр (без перезапроса)',
    build: build,
    act: (b) => b.add(const ApprovalsFilterChanged(ApprovalFilter.approved)),
    expect: () => [
      isA<ApprovalsState>()
          .having((s) => s.filter, 'filter', ApprovalFilter.approved),
    ],
    verify: (_) => verifyNever(() => load.call()),
  );

  blocTest<ApprovalsBloc, ApprovalsState>(
    'Decided(approve) → actionMessage + перезагрузка',
    setUp: () {
      when(() => load.call()).thenAnswer((_) async => queue);
      when(() => decide.call(
            id: any(named: 'id'),
            approve: any(named: 'approve'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});
    },
    build: build,
    act: (b) => b.add(
      const ApprovalsDecided(id: 1, approve: true, reason: 'ok'),
    ),
    expect: () => [
      isA<ApprovalsState>()
          .having((s) => s.actionMessage, 'actionMessage', 'Утверждено'),
      isA<ApprovalsState>()
          .having((s) => s.status, 'status', ApprovalsStatus.loading),
      isA<ApprovalsState>()
          .having((s) => s.status, 'status', ApprovalsStatus.success),
    ],
  );
}

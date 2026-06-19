import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/features/approvals/domain/models/my_request_filter.dart';
import 'package:mezzome/features/approvals/domain/use_cases/load_my_requests_use_case.dart';
import 'package:mezzome/features/approvals/presentation/blocs/my_requests_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoad extends Mock implements LoadMyRequestsUseCase {}

void main() {
  late _MockLoad load;

  setUpAll(() => registerFallbackValue(MyRequestFilter.pending));
  setUp(() => load = _MockLoad());

  MyRequestsBloc build() => MyRequestsBloc(load);

  blocTest<MyRequestsBloc, MyRequestsState>(
    'Requested → [loading, success]',
    setUp: () =>
        when(() => load.call(filter: any(named: 'filter'))).thenAnswer(
      (_) async => const [],
    ),
    build: build,
    act: (b) => b.add(const MyRequestsRequested()),
    expect: () => [
      isA<MyRequestsState>()
          .having((s) => s.status, 'status', MyRequestsStatus.loading),
      isA<MyRequestsState>()
          .having((s) => s.status, 'status', MyRequestsStatus.success),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'ошибка → [loading, failure]',
    setUp: () => when(() => load.call(filter: any(named: 'filter'))).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/')),
    ),
    build: build,
    act: (b) => b.add(const MyRequestsRequested()),
    expect: () => [
      isA<MyRequestsState>()
          .having((s) => s.status, 'status', MyRequestsStatus.loading),
      isA<MyRequestsState>()
          .having((s) => s.status, 'status', MyRequestsStatus.failure),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'FilterChanged меняет фильтр и перезапрашивает',
    setUp: () =>
        when(() => load.call(filter: any(named: 'filter'))).thenAnswer(
      (_) async => const [],
    ),
    build: build,
    act: (b) => b.add(const MyRequestsFilterChanged(MyRequestFilter.approved)),
    expect: () => [
      isA<MyRequestsState>()
          .having((s) => s.filter, 'filter', MyRequestFilter.approved),
      isA<MyRequestsState>()
          .having((s) => s.status, 'status', MyRequestsStatus.loading),
      isA<MyRequestsState>()
          .having((s) => s.status, 'status', MyRequestsStatus.success),
    ],
    verify: (_) =>
        verify(() => load.call(filter: MyRequestFilter.approved)).called(1),
  );
}

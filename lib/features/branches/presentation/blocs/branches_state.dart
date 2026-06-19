part of 'branches_bloc.dart';

enum BranchesStatus { initial, loading, success, failure }

class BranchesState extends Equatable {
  const BranchesState({
    this.status = BranchesStatus.initial,
    this.result,
    this.period = 'week',
    this.selectedId,
  });

  final BranchesStatus status;
  final ObjectsFinance? result;
  final String period;

  /// `null` = выбран агрегат «Все».
  final int? selectedId;

  bool get isLoading => status == BranchesStatus.loading;

  List<ObjectFinance> get objects => result?.objects ?? const [];
  bool get canViewMoney => result?.canViewMoney ?? true;

  /// Карточки под выбранный чип: «Все» → агрегат, иначе выбранный объект.
  List<ObjectFinance> get visible {
    if (selectedId == null) {
      return objects.where((o) => o.isAll).toList();
    }
    return objects.where((o) => o.id == selectedId).toList();
  }

  BranchesState copyWith({
    BranchesStatus? status,
    ObjectsFinance? result,
    bool clearResult = false,
    String? period,
    int? selectedId,
    bool clearSelected = false,
  }) {
    return BranchesState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      period: period ?? this.period,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
    );
  }

  @override
  List<Object?> get props => [status, result, period, selectedId];
}

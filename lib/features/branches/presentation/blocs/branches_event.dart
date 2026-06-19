part of 'branches_bloc.dart';

sealed class BranchesEvent extends Equatable {
  const BranchesEvent();

  @override
  List<Object?> get props => [];
}

class BranchesRequested extends BranchesEvent {
  const BranchesRequested();
}

class BranchesRefreshed extends BranchesEvent {
  const BranchesRefreshed();
}

class BranchesPeriodChanged extends BranchesEvent {
  const BranchesPeriodChanged(this.period);

  final String period;

  @override
  List<Object?> get props => [period];
}

/// Выбор чипа объекта. `null` = «Все».
class BranchSelected extends BranchesEvent {
  const BranchSelected(this.id);

  final int? id;

  @override
  List<Object?> get props => [id];
}

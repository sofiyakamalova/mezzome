part of 'nutrition_bloc.dart';

sealed class NutritionEvent extends Equatable {
  const NutritionEvent();

  @override
  List<Object?> get props => [];
}

class NutritionRequested extends NutritionEvent {
  const NutritionRequested();
}

class NutritionRefreshed extends NutritionEvent {
  const NutritionRefreshed();
}

class NutritionPeriodChanged extends NutritionEvent {
  const NutritionPeriodChanged(this.period);

  final String period;

  @override
  List<Object?> get props => [period];
}

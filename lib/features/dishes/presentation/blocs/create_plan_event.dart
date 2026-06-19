part of 'create_plan_bloc.dart';

sealed class CreatePlanEvent extends Equatable {
  const CreatePlanEvent();

  @override
  List<Object?> get props => [];
}

class CreatePlanStarted extends CreatePlanEvent {
  const CreatePlanStarted();
}

class CreatePlanRetryBootstrap extends CreatePlanEvent {
  const CreatePlanRetryBootstrap();
}

class PlanServiceChanged extends CreatePlanEvent {
  const PlanServiceChanged(this.service);
  final MenuServiceType service;
  @override
  List<Object?> get props => [service];
}

class PlanDateChanged extends CreatePlanEvent {
  const PlanDateChanged(this.date);
  final DateTime date;
  @override
  List<Object?> get props => [date];
}

class PlanKitchenChanged extends CreatePlanEvent {
  const PlanKitchenChanged(this.kitchenId);
  final int? kitchenId;
  @override
  List<Object?> get props => [kitchenId];
}

class PlanPeopleChanged extends CreatePlanEvent {
  const PlanPeopleChanged(this.value);
  final int? value;
  @override
  List<Object?> get props => [value];
}

class PlanReserveChanged extends CreatePlanEvent {
  const PlanReserveChanged(this.value);
  final double? value;
  @override
  List<Object?> get props => [value];
}

class PlanNotesChanged extends CreatePlanEvent {
  const PlanNotesChanged(this.value);
  final String? value;
  @override
  List<Object?> get props => [value];
}

class PlanItemAdded extends CreatePlanEvent {
  const PlanItemAdded();
}

class PlanItemRemoved extends CreatePlanEvent {
  const PlanItemRemoved(this.key);
  final int key;
  @override
  List<Object?> get props => [key];
}

class PlanItemDishChanged extends CreatePlanEvent {
  const PlanItemDishChanged(this.key, this.menuItemId);
  final int key;
  final int? menuItemId;
  @override
  List<Object?> get props => [key, menuItemId];
}

class PlanItemPortionsChanged extends CreatePlanEvent {
  const PlanItemPortionsChanged(this.key, this.portions);
  final int key;
  final int? portions;
  @override
  List<Object?> get props => [key, portions];
}

class PlanSubmitted extends CreatePlanEvent {
  const PlanSubmitted();
}

class PlanFormReset extends CreatePlanEvent {
  const PlanFormReset();
}

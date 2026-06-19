part of 'nutrition_bloc.dart';

enum NutritionStatus { initial, loading, success, failure }

class NutritionState extends Equatable {
  const NutritionState({
    this.status = NutritionStatus.initial,
    this.data,
    this.period = 'month',
  });

  final NutritionStatus status;
  final NutritionDashboard? data;
  final String period;

  bool get isLoading => status == NutritionStatus.loading;

  NutritionState copyWith({
    NutritionStatus? status,
    NutritionDashboard? data,
    bool clearData = false,
    String? period,
  }) {
    return NutritionState(
      status: status ?? this.status,
      data: clearData ? null : (data ?? this.data),
      period: period ?? this.period,
    );
  }

  @override
  List<Object?> get props => [status, data, period];
}

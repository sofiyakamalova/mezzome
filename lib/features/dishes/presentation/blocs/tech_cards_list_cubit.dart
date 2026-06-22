import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';
import 'package:mezzome/features/dishes/data/repository/menu_dashboard_repository.dart';

part 'tech_cards_list_state.dart';

/// Список всех техкарт (вкладка «Техкарты»).
class TechCardsListCubit extends Cubit<TechCardsListState> {
  TechCardsListCubit(this._repo) : super(const TechCardsListState());

  final MenuDashboardRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: TechCardsListStatus.loading, clearError: true));
    try {
      final cards = await _repo.listAllTechnicalCards();
      emit(state.copyWith(
        status: TechCardsListStatus.success,
        cards: cards,
      ));
    } on DioException catch (e) {
      appLogger.w('Tech cards list failed: ${e.response?.statusCode}');
      emit(state.copyWith(
        status: TechCardsListStatus.failure,
        error: 'HTTP ${e.response?.statusCode}',
      ));
    }
  }

  void setSearch(String query) => emit(state.copyWith(query: query));
}

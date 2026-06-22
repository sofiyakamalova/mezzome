part of 'tech_cards_list_cubit.dart';

enum TechCardsListStatus { initial, loading, success, failure }

class TechCardsListState {
  const TechCardsListState({
    this.status = TechCardsListStatus.initial,
    this.cards = const [],
    this.query = '',
    this.error,
  });

  final TechCardsListStatus status;
  final List<TechnicalCardModel> cards;
  final String query;
  final String? error;

  bool get isLoading => status == TechCardsListStatus.loading;

  /// Карты под поисковый запрос (по имени/коду).
  List<TechnicalCardModel> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return cards;
    return cards
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.code ?? '').toLowerCase().contains(q))
        .toList();
  }

  TechCardsListState copyWith({
    TechCardsListStatus? status,
    List<TechnicalCardModel>? cards,
    String? query,
    String? error,
    bool clearError = false,
  }) {
    return TechCardsListState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

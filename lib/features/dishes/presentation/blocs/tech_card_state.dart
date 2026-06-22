part of 'tech_card_cubit.dart';

enum TechCardStatus { loading, ready, notFound }

class TechCardData {
  const TechCardData({
    required this.card,
    required this.history,
    required this.scale,
  });

  final TechnicalCardModel card;
  final TechCardHistoryResult history;
  final ScaleVarianceResult scale;
}

class TechCardState {
  const TechCardState._(this.status, this.data);

  const TechCardState.loading() : this._(TechCardStatus.loading, null);
  const TechCardState.notFound() : this._(TechCardStatus.notFound, null);
  const TechCardState.ready(TechCardData data)
      : this._(TechCardStatus.ready, data);

  final TechCardStatus status;
  final TechCardData? data;
}

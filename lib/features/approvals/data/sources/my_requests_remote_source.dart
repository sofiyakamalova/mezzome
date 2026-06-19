import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/dishes/data/api/technical_cards_api.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';

/// Сырой доступ к списку моих техкарт-запросов (Retrofit).
class MyRequestsRemoteSource {
  const MyRequestsRemoteSource(this._api);

  final TechnicalCardsApi _api;

  Future<List<TechnicalCardModel>> fetch({required String status}) async {
    final res = await _api.listTechnicalCards(
      status: status,
      includeAllVersions: true,
    );
    appLogger.i('My requests (status=$status): ${res.cards.length} cards');
    return res.cards;
  }
}

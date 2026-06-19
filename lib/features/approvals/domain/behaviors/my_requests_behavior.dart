import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';

/// Контракт «Мои запросы на изменение». Возвращает общие [TechnicalCardModel]
/// (общие модели техкарт намеренно живут в data/ — см. решение по dishes).
abstract class MyRequestsBehavior {
  Future<List<TechnicalCardModel>> fetchMyRequests({required String status});
}

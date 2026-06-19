import 'package:mezzome/features/approvals/domain/behaviors/my_requests_behavior.dart';
import 'package:mezzome/features/approvals/domain/models/my_request_filter.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';

/// Загрузить мои запросы по выбранному фильтру (фильтрация — на сервере).
class LoadMyRequestsUseCase {
  const LoadMyRequestsUseCase(this._behavior);

  final MyRequestsBehavior _behavior;

  Future<List<TechnicalCardModel>> call({required MyRequestFilter filter}) =>
      _behavior.fetchMyRequests(status: filter.statusValue);
}

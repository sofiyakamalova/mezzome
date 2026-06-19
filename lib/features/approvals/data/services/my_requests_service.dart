import 'package:mezzome/features/approvals/data/sources/my_requests_remote_source.dart';
import 'package:mezzome/features/approvals/domain/behaviors/my_requests_behavior.dart';
import 'package:mezzome/features/dishes/data/models/technical_card_model.dart';

class MyRequestsService implements MyRequestsBehavior {
  const MyRequestsService(this._source);

  final MyRequestsRemoteSource _source;

  @override
  Future<List<TechnicalCardModel>> fetchMyRequests({required String status}) =>
      _source.fetch(status: status);
}

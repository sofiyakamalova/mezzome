import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';

/// Создание ингредиента в справочник (owner/admin). Бэкенд: `POST /owner/inventory`
/// (alias `POST /admin/ingredients`), тело — `dto.IngredientCreateRequest`.
/// Шеф этим не пользуется — только выбирает из готового справочника.
class IngredientCreateService {
  IngredientCreateService(this._dio);

  final Dio _dio;

  /// Создаёт ингредиент. Минимальный набор полей (обязателен только `name`).
  /// Возвращает `true` при успехе; бросает [DioException] при ошибке.
  Future<bool> create({
    required String name,
    String? category,
    String? unit,
    double? price,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (category != null && category.isNotEmpty) body['category'] = category;
    if (unit != null && unit.isNotEmpty) {
      body['unit'] = unit;
      body['base_unit'] = unit;
      // Бэк требует NOT NULL `canonical_unit`, но из `unit` его не выводит —
      // дублируем явно (canonical-код kg/gr/l/ml/pieces). См. BACKEND_ISSUES.
      body['canonical_unit'] = unit;
      body['quantity_unit'] = unit;
    }
    if (price != null) body['price'] = price;
    appLogger.i('POST /owner/inventory: $body');
    final res = await _dio.post<dynamic>('/owner/inventory', data: body);
    appLogger.i('Ingredient created (HTTP ${res.statusCode})');
    return true;
  }
}

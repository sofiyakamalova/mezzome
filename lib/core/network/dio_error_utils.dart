import 'package:dio/dio.dart';

String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final code = data['error'];
    if (code is String) {
      return code;
    }
  }
  return null;
}

/// Человекочитаемая причина из тела ответа: `details`, иначе `message`,
/// иначе код `error`. `null`, если ничего нет (например, сетевая ошибка).
String? apiErrorDetails(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    for (final key in const ['details', 'message', 'error']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
  }
  return null;
}

bool isApiForbidden(DioException error) =>
    error.response?.statusCode == 403 &&
    (apiErrorCode(error) == 'FORBIDDEN' || apiErrorCode(error) == null);

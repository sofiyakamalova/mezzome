import 'package:dio/dio.dart';
import 'package:mezzome/core/logging/app_logger.dart';

/// Загрузка изображений на бэкенд (`POST /uploads/image`, multipart, поле
/// `image`). Возвращает `file_url` для сохранения в `photo_urls` техкарты.
class ImageUploadService {
  ImageUploadService(this._dio);

  final Dio _dio;

  Future<String?> uploadImage({
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _dio.post<dynamic>('/uploads/image', data: form);
      final data = res.data;
      final url = data is Map ? data['file_url']?.toString() : null;
      if (url == null || url.isEmpty) {
        appLogger.w('Image upload: empty file_url in response');
        return null;
      }
      appLogger.i('Image uploaded: $url');
      return url;
    } on DioException catch (e) {
      appLogger.w('Image upload failed (HTTP ${e.response?.statusCode}): '
          '${e.response?.data ?? e.message}');
      return null;
    }
  }
}

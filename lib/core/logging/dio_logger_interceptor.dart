import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/logging/http_log_utils.dart';

/// HTTP logging via [appLogger]. Error responses log raw body at [Level.info].
class DioLoggerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    appLogger.i('HTTP → ${options.method} ${options.uri}');
    if (kDebugMode && options.data != null) {
      appLogger.d('Request body:\n${formatRawHttpPayload(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    appLogger.i(
      'HTTP ← ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}',
    );
    if (kDebugMode && response.data != null) {
      appLogger.i('Response raw:\n${formatRawHttpPayload(response.data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final path = err.requestOptions.uri.path;
    final isTechCardDetailGet = err.requestOptions.method == 'GET' &&
        RegExp(r'/technical-cards/\d+$').hasMatch(path);

    if (isTechCardDetailGet && status != null && status >= 500) {
      appLogger.w(
        'HTTP $status ${err.requestOptions.method} ${err.requestOptions.uri} '
        '(technical card detail — handled on client)',
      );
    } else {
      appLogger.e(
        'HTTP ✗ ${err.requestOptions.method} ${err.requestOptions.uri} '
        'status=$status type=${err.type}',
        error: err,
        stackTrace: err.stackTrace,
      );
    }

    final response = err.response;
    if (response != null) {
      appLogger.i('HTTP error raw status: $status');
      appLogger.i('HTTP error raw headers: ${response.headers.map}');
      appLogger.i(
        'HTTP error raw body:\n${formatRawHttpPayload(response.data)}',
      );
    } else {
      appLogger.i('HTTP error raw body: <no response>');
    }

    handler.next(err);
  }
}

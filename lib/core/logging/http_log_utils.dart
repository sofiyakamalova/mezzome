import 'dart:convert';

/// Formats Dio/HTTP payload for console logs.
String formatRawHttpPayload(dynamic data) {
  if (data == null) {
    return '<empty>';
  }
  if (data is String) {
    return data.isEmpty ? '<empty string>' : data;
  }
  if (data is Map || data is List) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
  return data.toString();
}

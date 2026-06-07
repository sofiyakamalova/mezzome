import 'package:mezzome/features/auth/domain/kazakhstan_phone_mask_formatter.dart';

/// Normalizes KZ phone numbers to +7XXXXXXXXXX.
String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');

  if (digits.isEmpty) {
    return raw.trim();
  }

  if (digits.startsWith('8') && digits.length == 11) {
    return '+7${digits.substring(1)}';
  }

  if (digits.startsWith('7') && digits.length == 11) {
    return '+$digits';
  }

  if (digits.length == 10) {
    return '+7$digits';
  }

  if (raw.trim().startsWith('+')) {
    return '+$digits';
  }

  return '+$digits';
}

bool isValidPhone(String raw) {
  final normalized = normalizePhone(raw);
  return RegExp(r'^\+7\d{10}$').hasMatch(normalized);
}

String formatPhoneForDisplay(String phone) {
  final normalized = normalizePhone(phone);
  if (!RegExp(r'^\+7\d{10}$').hasMatch(normalized)) {
    return phone;
  }
  final national = normalized.substring(2);
  return KazakhstanPhoneMask.formatNationalDigits(national);
}

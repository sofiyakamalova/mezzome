import 'package:flutter/services.dart';

/// KZ login mask: `+7 900 000 00 03` (10 national digits, no extra input).
abstract final class KazakhstanPhoneMask {
  static const String prefix = '+7 ';
  static const int maxNationalDigits = 10;
  static const int maxFormattedLength = 16;

  static String formatNationalDigits(String digits) {
    if (digits.isEmpty) {
      return prefix;
    }
    final capped = digits.length > maxNationalDigits
        ? digits.substring(0, maxNationalDigits)
        : digits;
    final buffer = StringBuffer(prefix);
    for (var i = 0; i < capped.length; i++) {
      if (i == 3 || i == 6 || i == 8) {
        buffer.write(' ');
      }
      buffer.write(capped[i]);
    }
    return buffer.toString();
  }

  static String extractNationalDigits(String text) {
    var digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('7')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('8')) {
      digits = digits.substring(1);
    }
    if (digits.length > maxNationalDigits) {
      digits = digits.substring(0, maxNationalDigits);
    }
    return digits;
  }
}

/// Input mask for login phone field.
class KazakhstanPhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final national = KazakhstanPhoneMask.extractNationalDigits(newValue.text);
    final formatted = KazakhstanPhoneMask.formatNationalDigits(national);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

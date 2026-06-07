import 'package:flutter/material.dart';

/// MEZZOME design tokens (§11 ТЗ).
abstract final class AppColors {
  /// Brand primary — синий акцент (как в светлой теме).
  static const Color primary = Color(0xFF185FA5);

  /// Текст/иконки поверх синей заливки — белый.
  static const Color onPrimary = Color(0xFFFFFFFF);
  /// Статусные цвета (единая семантика расхода для обеих тем).
  /// Норма / отклонение / перерасход / черновик.
  static const Color profitGreen = Color(0xFF1D9E75);
  static const Color dangerRed = Color(0xFFE24B4A);
  static const Color warningAmber = Color(0xFFEF9F27);
  static const Color statusDraft = Color(0xFF9AA0A6);

  static const Color background = Color(0xFF0F1114);
  static const Color surface = Color(0xFF1A1D22);
  static const Color surfaceElevated = Color(0xFF242830);
  static const Color border = Color(0xFF2E343D);
  static const Color textPrimary = Color(0xFFF4F5F7);
  static const Color textSecondary = Color(0xFF9AA3AD);
}

import 'package:flutter/material.dart';

/// Light theme surface tokens — чистая профессиональная тема с синим акцентом.
abstract final class AppColorsLight {
  /// Основной фон страницы — очень светлый холодно-серый.
  static const Color background = Color(0xFFF4F6F8);
  static const Color whiteColor = Color.fromARGB(255, 255, 255, 255);

  /// Поверхности карточек, полей ввода, строк таблицы.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Вторичные поверхности: шапки таблиц, неактивные табы, заголовки ячеек.
  static const Color surfaceSecondary = Color(0xFFF3F4F6);

  static const Color border = Color(0xFFE5E7EB);

  /// Разделители внутри карточек/строк — чуть светлее основной границы.
  static const Color divider = Color(0xFFF0F1F3);

  static const Color textPrimary = Color(0xFF1A1D1A);
  static const Color textSecondary = Color(0xFF9AA0A6);
  static const Color textTertiary = Color(0xFFB5BAC0);

  /// Основной синий акцент.
  static const Color primary = Color(0xFF185FA5);

  /// Затемнённый акцент для hover/нажатия.
  static const Color primaryPressed = Color(0xFF0C447C);

  /// Текст поверх акцента (CTA-кнопки) — белый.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Светлая заливка акцента: фон активного таба, бейджи, иконки в кружке.
  static const Color accentSoft = Color(0xFFE6F1FB);

  /// Более насыщенная светлая заливка (активный сервис-таб).
  static const Color accentSoftStrong = Color(0xFFB5D4F4);

  /// Тёмный текст поверх светло-синей заливки (никогда не серый/чёрный).
  static const Color onAccentSoft = Color(0xFF0C447C);
  static const Color onAccentSoftStrong = Color(0xFF042C53);

  /// Кольцо фокуса поля ввода.
  static const Color focusRing = Color(0xFFE6F1FB);
}

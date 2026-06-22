import 'package:flutter/material.dart';

/// Единая палитра и текстовые стили страницы технологической карты.
class AppColors {
  static const Color primary = Color(0xFF2F80ED); // синий MEZZOME / кнопки
  static const Color primaryLight = Color(0xFFEAF2FE); // фон чипов / заголовков секций
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE6E8EC);
  static const Color tableBorder = Color(0xFFE9ECF1);
  static const Color textDark = Color(0xFF1A1D1F);
  static const Color textBody = Color(0xFF33373D);
  static const Color textMuted = Color(0xFF9AA0A6);
  static const Color textLabel = Color(0xFF8A9099);
  static const Color chipBorder = Color(0xFFBFD7F5);
  static const Color draftBg = Color(0xFFF1F3F5);
  static const Color divider = Color(0xFFECEEF0);
  static const Color placeholder = Color(0xFFC9CDD2);

  // роли в истории изменений
  static const Color roleManager = Color(0xFF2F80ED);
  static const Color roleTechnologist = Color(0xFF2F80ED);
  static const Color roleChef = Color(0xFF2F80ED);
}

class AppText {
  static const String fontFamily = 'Roboto';

  static const TextStyle h1 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    height: 1.15,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textLabel,
  );

  static const TextStyle valueBig = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    height: 1.45,
    color: AppColors.textBody,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 13.5,
    height: 1.45,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle tableHeader = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );

  static const TextStyle tableCell = TextStyle(
    fontSize: 13,
    color: AppColors.textBody,
  );

  static const TextStyle chip = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  );
}

class AppRadius {
  static const double card = 14;
  static const double chip = 8;
  static const double image = 12;
  static const double button = 10;
}

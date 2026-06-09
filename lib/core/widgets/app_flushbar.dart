import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';

/// Единая точка показа всплывающих уведомлений (вместо `SnackBar`).
///
/// Рисует тематический Flushbar сверху: фон карточки, цветная полоса/иконка
/// слева по типу сообщения (ошибка/успех/инфо) и текст в цвете темы.
abstract final class AppFlushbar {
  /// Ошибка — красная полоса и иконка.
  static void showError(BuildContext context, String message) =>
      _show(context, message, _FlushKind.error);

  /// Успешное действие — зелёная полоса и галочка.
  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, _FlushKind.success);

  /// Нейтральное уведомление — акцентная (синяя) полоса.
  static void showInfo(BuildContext context, String message) =>
      _show(context, message, _FlushKind.info);

  /// Удобный шорткат: ошибка, если [isError], иначе инфо.
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) => isError ? showError(context, message) : showInfo(context, message);

  static void _show(BuildContext context, String message, _FlushKind kind) {
    final (Color accent, IconData icon) = switch (kind) {
      _FlushKind.error => (AppColors.dangerRed, Icons.error_outline_rounded),
      _FlushKind.success => (
        AppColors.profitGreen,
        Icons.check_circle_outline_rounded,
      ),
      _FlushKind.info => (
        ThemePalette.accent(context),
        Icons.info_outline_rounded,
      ),
    };

    Flushbar<void>(
      message: message,
      messageColor: ThemePalette.onSurface(context),
      messageSize: 14,
      icon: Icon(icon, color: accent),
      // leftBarIndicatorColor: accent,
      backgroundColor: ThemePalette.surfaceCard(context),
      borderColor: ThemePalette.border(context),
      borderWidth: 1,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      margin: const EdgeInsets.all(AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 4,
      ),
      flushbarPosition: FlushbarPosition.TOP,
      flushbarStyle: FlushbarStyle.FLOATING,
      duration: Duration(seconds: kind == _FlushKind.error ? 4 : 3),
      animationDuration: const Duration(milliseconds: 280),
      isDismissible: true,
    ).show(context);
  }
}

enum _FlushKind { info, success, error }

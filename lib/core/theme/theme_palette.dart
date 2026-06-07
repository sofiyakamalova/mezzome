import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';

/// Semantic colors that follow light (bordered, white) vs dark (filled) UI.
abstract final class ThemePalette {
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  /// Синий акцент (один и тот же в обеих темах).
  static Color accent(BuildContext context) =>
      isLight(context) ? AppColorsLight.primary : AppColors.primary;

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color onSurfaceMuted(BuildContext context) => isLight(context)
      ? AppColorsLight.onAccentSoftStrong
      : AppColors.textSecondary;

  static Color surfaceCard(BuildContext context) =>
      isLight(context) ? Colors.white : AppColors.surfaceElevated;

  static Color surfacePanel(BuildContext context) =>
      isLight(context) ? Colors.white : AppColors.surface;

  static Color border(BuildContext context) =>
      isLight(context) ? AppColorsLight.border : AppColors.border;

  static Color controlFill(BuildContext context, {required bool selected}) {
    if (isLight(context)) {
      return selected ? AppColorsLight.accentSoft : Colors.white;
    }
    return selected ? accent(context) : AppColors.surfaceElevated;
  }

  static BorderSide controlBorder(
    BuildContext context, {
    required bool selected,
    bool highlight = false,
  }) {
    if (isLight(context)) {
      if (selected || highlight) {
        return BorderSide(color: accent(context), width: selected ? 1 : 0.5);
      }
      return const BorderSide(color: AppColorsLight.border, width: 0.5);
    }
    if (selected) {
      return BorderSide(color: accent(context), width: 2);
    }
    if (highlight) {
      return BorderSide(color: accent(context).withValues(alpha: 0.5));
    }
    return const BorderSide(color: AppColors.border);
  }

  static Color chipLabelColor(
    BuildContext context, {
    required bool selected,
    bool accent = false,
  }) {
    if (isLight(context)) {
      if (selected) {
        return AppColorsLight.onAccentSoft;
      }
      if (accent) {
        return ThemePalette.accent(context);
      }
      return onSurface(context);
    }
    if (selected) {
      return AppColors.onPrimary;
    }
    if (accent) {
      return ThemePalette.accent(context);
    }
    return AppColors.textPrimary;
  }

  static Color chipMutedLabelColor(
    BuildContext context, {
    required bool selected,
  }) {
    if (isLight(context)) {
      return onSurfaceMuted(context);
    }
    return selected ? AppColors.onPrimary : AppColors.textSecondary;
  }

  static ButtonStyle segmentedControlStyle(BuildContext context) {
    return ButtonStyle(
      side: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (isLight(context)) {
          return BorderSide(
            color: selected ? accent(context) : AppColorsLight.border,
            width: selected ? 1.5 : 1,
          );
        }
        return BorderSide.none;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (isLight(context)) {
          return selected ? AppColorsLight.accentSoft : Colors.white;
        }
        return selected ? accent(context) : AppColors.surfaceElevated;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (isLight(context)) {
          return selected ? AppColorsLight.onAccentSoft : onSurface(context);
        }
        return selected ? AppColors.onPrimary : AppColors.textPrimary;
      }),
    );
  }

  static ButtonStyle toolbarButtonStyle(
    BuildContext context, {
    required bool filled,
  }) {
    if (isLight(context)) {
      return FilledButton.styleFrom(
        backgroundColor: filled ? AppColorsLight.accentSoft : Colors.white,
        foregroundColor: filled
            ? AppColorsLight.onAccentSoft
            : onSurface(context),
        side: BorderSide(
          color: filled
              ? AppColorsLight.accentSoftStrong
              : AppColorsLight.border,
        ),
      );
    }
    return FilledButton.styleFrom(
      backgroundColor: filled ? accent(context) : AppColors.surfaceElevated,
      foregroundColor: filled ? AppColors.onPrimary : AppColors.textPrimary,
    );
  }
}

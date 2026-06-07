import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';

/// Сегмент-контрол приёма пищи: Завтрак · Обед · Ужин.
/// Активная таблетка заливается акцентом, переключение анимировано.
class ServiceTabs extends StatelessWidget {
  const ServiceTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MenuServiceType selected;
  final ValueChanged<MenuServiceType> onSelected;

  static IconData _iconFor(MenuServiceType service) => switch (service) {
    MenuServiceType.breakfast => Icons.free_breakfast_rounded,
    MenuServiceType.lunch => Icons.lunch_dining_rounded,
    MenuServiceType.dinner => Icons.dinner_dining_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final track = ThemePalette.isLight(context)
        ? AppColorsLight.surface
        : AppColors.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: ThemePalette.border(context)),
        ),
        child: Row(
          children: [
            for (final service in MenuServiceType.values)
              Expanded(
                child: _Tab(
                  service: service,
                  isActive: service == selected,
                  onTap: () => onSelected(service),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.service,
    required this.isActive,
    required this.onTap,
  });

  final MenuServiceType service;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final track = ThemePalette.isLight(context)
        ? AppColorsLight.surface
        : AppColors.surface;

    final isLight = ThemePalette.isLight(context);
    // Светлая тема: активный таб — мягко-синяя заливка с тёмно-синим текстом
    // (без свечения). Тёмная: сплошной акцент.
    final activeFill = isLight
        ? AppColorsLight.accentSoftStrong
        : ThemePalette.accent(context);
    final activeText = isLight
        ? AppColorsLight.onAccentSoftStrong
        : AppColors.onPrimary;
    final inactiveText = ThemePalette.onSurfaceMuted(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? activeFill : track, //Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ServiceTabs._iconFor(service),
              size: 16,
              color: isActive ? activeText : inactiveText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                service.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isActive ? activeText : inactiveText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

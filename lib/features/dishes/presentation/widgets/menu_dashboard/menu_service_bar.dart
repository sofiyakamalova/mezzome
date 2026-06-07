import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/features/dishes/domain/menu_service_type.dart';

class MenuServiceBar extends StatelessWidget {
  const MenuServiceBar({
    super.key,
    required this.selectedService,
    required this.positionCount,
    required this.changedCount,
    required this.weeklyCost,
    required this.showFinancials,
    required this.onServiceSelected,
  });

  final MenuServiceType selectedService;
  final int positionCount;
  final int changedCount;
  final double weeklyCost;
  final bool showFinancials;
  final ValueChanged<MenuServiceType> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SegmentedButton<MenuServiceType>(
            segments: MenuServiceType.values
                .map(
                  (service) => ButtonSegment(
                    value: service,
                    label: Text(service.label),
                  ),
                )
                .toList(),
            selected: {selectedService},
            onSelectionChanged: (set) => onServiceSelected(set.first),
            style: ThemePalette.segmentedControlStyle(context),
          ),
          const SizedBox(width: AppSpacing.lg),
          _Stat(label: 'statPositions'.tr(), value: '$positionCount'),
          const SizedBox(width: AppSpacing.md),
          _Stat(label: 'statChanged'.tr(), value: '$changedCount'),
          if (showFinancials) ...[
            const SizedBox(width: AppSpacing.md),
            _Stat(
              label: 'statWeeklyCost'.tr(),
              value: '${weeklyCost.toStringAsFixed(0)} ₸',
            ),
          ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ThemePalette.onSurfaceMuted(context),
                letterSpacing: 0.6,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

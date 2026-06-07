import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';

/// Заголовок AppBar меню-борда: логотип, MEZZOME, подпись.
class MenuDashboardAppBarTitle extends StatelessWidget {
  const MenuDashboardAppBarTitle({super.key, required this.signature});

  final String signature;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ThemePalette.surfaceCard(context),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: ThemePalette.accent(context),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.restaurant,
                color: ThemePalette.accent(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'MEZZOME',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: ThemePalette.surfaceCard(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: ThemePalette.border(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_circle,
                size: 14,
                color: ThemePalette.accent(context),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  signature,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

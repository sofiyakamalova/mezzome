import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/utils/date_format.dart';

/// Недельный навигатор для меню-борда: «‹ 1–7 июня 2026 ›» + возврат на
/// текущую неделю. Заменяет подневный пикер — таблица всегда про неделю.
class WeekRangeSelector extends StatelessWidget {
  const WeekRangeSelector({
    super.key,
    required this.weekStart,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final normalizedStart = DateFormatUtil.startOfWeek(weekStart);
    final currentStart = DateFormatUtil.startOfWeek(DateFormatUtil.today);
    final isCurrentWeek =
        DateFormatUtil.isSameDay(normalizedStart, currentStart);
    final range = DateFormatUtil.formatWeekRange(normalizedStart, locale);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ThemePalette.surfaceCard(context),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: ThemePalette.border(context)),
              ),
              child: Row(
                children: [
                  _ArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPrev,
                    tooltip: 'weekPrev'.tr(),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'weekLabel'.tr(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: ThemePalette.onSurfaceMuted(context),
                                    letterSpacing: 0.6,
                                  ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          range,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _ArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNext,
                    tooltip: 'weekNext'.tr(),
                  ),
                ],
              ),
            ),
          ),
          if (!isCurrentWeek) ...[
            const SizedBox(width: AppSpacing.xs),
            _TodayButton(onTap: onToday),
          ],
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: ThemePalette.onSurface(context),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ThemePalette.accent(context),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 14,
          ),
          child: Text(
            'weekToday'.tr(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

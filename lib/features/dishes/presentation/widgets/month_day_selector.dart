import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/l10n/weekday_labels.dart';
import 'package:mezzome/core/utils/date_format.dart';

/// Month navigation + horizontally scrollable days (current year only).
class MonthDaySelector extends StatefulWidget {
  const MonthDaySelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<MonthDaySelector> createState() => _MonthDaySelectorState();
}

class _MonthDaySelectorState extends State<MonthDaySelector> {
  static const _chipWidth = 52.0;
  static const _separatorWidth = AppSpacing.xs;

  late final ScrollController _daysScrollController;

  DateTime get _selected => DateFormatUtil.normalizeScheduleDate(widget.selectedDate);

  @override
  void initState() {
    super.initState();
    _daysScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
  }

  @override
  void didUpdateWidget(MonthDaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSelected = DateFormatUtil.normalizeScheduleDate(oldWidget.selectedDate);
    if (!_isSameMonth(oldSelected, _selected) ||
        oldSelected.day != _selected.day) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDay());
    }
  }

  @override
  void dispose() {
    _daysScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDay() {
    if (!_daysScrollController.hasClients) {
      return;
    }
    final index = _selected.day - 1;
    final offset = index * (_chipWidth + _separatorWidth);
    final max = _daysScrollController.position.maxScrollExtent;
    _daysScrollController.animateTo(
      offset.clamp(0.0, max),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _shiftMonth(int delta) {
    final month = _selected.month + delta;
    if (month < 1 || month > 12) {
      return;
    }
    widget.onDateSelected(
      DateFormatUtil.clampDayInMonth(
        _selected,
        DateFormatUtil.currentYear,
        month,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final monthTitle = DateFormat.yMMMM(locale).format(_selected);
    final days = DateFormatUtil.daysInMonth(_selected);
    final weekdayLabels = localizedWeekdayLabels();
    final canGoPrev = _selected.month > 1;
    final canGoNext = _selected.month < 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                onPressed: canGoPrev ? () => _shiftMonth(-1) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'previousMonth'.tr(),
              ),
              Expanded(
                child: Text(
                  monthTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: canGoNext ? () => _shiftMonth(1) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'nextMonth'.tr(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 96,
          child: ListView.separated(
            controller: _daysScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: days.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: _separatorWidth),
            itemBuilder: (context, index) {
              final date = days[index];
              final isSelected = DateFormatUtil.isSameDay(date, _selected);
              final isToday = DateFormatUtil.isToday(date);
              final label = weekdayLabels[date.weekday - DateTime.monday];

              return _DayChip(
                label: label,
                day: date.day,
                isSelected: isSelected,
                isToday: isToday,
                onTap: () => widget.onDateSelected(date),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final int day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppSpacing.radiusSm);
    final showTodayRing = isToday && !isSelected;

    return Material(
      color: ThemePalette.controlFill(context, selected: isSelected),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: ThemePalette.controlBorder(
          context,
          selected: isSelected,
          highlight: showTodayRing,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: SizedBox(
          width: _MonthDaySelectorState._chipWidth,
          height: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxs,
              horizontal: 2,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isToday)
                  Text(
                    'todayShort'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ThemePalette.chipLabelColor(
                        context,
                        selected: isSelected,
                        accent: isToday,
                      ),
                      fontWeight: FontWeight.w600,
                      fontSize: 8,
                      height: 1.1,
                    ),
                  ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ThemePalette.chipMutedLabelColor(
                      context,
                      selected: isSelected,
                    ),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
                Text(
                  '$day',
                  maxLines: 1,
                  style: TextStyle(
                    color: ThemePalette.chipLabelColor(
                      context,
                      selected: isSelected,
                    ),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

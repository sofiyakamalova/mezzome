import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/l10n/weekday_labels.dart';

class MenuConsumptionChart extends StatelessWidget {
  const MenuConsumptionChart({
    super.key,
    required this.consumptionByDay,
    required this.weekDays,
  });

  final Map<int, double> consumptionByDay;
  final List<DateTime> weekDays;

  @override
  Widget build(BuildContext context) {
    if (weekDays.isEmpty) {
      return const SizedBox.shrink();
    }

    final labels = localizedWeekdayLabels();
    final spots = <FlSpot>[];
    var maxY = 0.0;
    for (var i = 0; i < weekDays.length; i++) {
      final value = consumptionByDay[i] ?? 0;
      maxY = value > maxY ? value : maxY;
      spots.add(FlSpot(i.toDouble(), value));
    }
    if (maxY <= 0) {
      maxY = 100;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'consumptionChartTitle'.tr(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: ThemePalette.onSurfaceMuted(context),
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (weekDays.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: ThemePalette.border(context),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value >= 1000
                            ? '${(value / 1000).toStringAsFixed(0)}k'
                            : value.toStringAsFixed(0),
                        style: TextStyle(
                          color: ThemePalette.onSurfaceMuted(context),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= weekDays.length) {
                          return const SizedBox.shrink();
                        }
                        final weekday = weekDays[index].weekday;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[weekday - DateTime.monday],
                            style: TextStyle(
                              color: ThemePalette.onSurfaceMuted(context),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: ThemePalette.accent(context),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: ThemePalette.accent(context),
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: ThemePalette.accent(context).withValues(
                        alpha: ThemePalette.isLight(context) ? 0.06 : 0.12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:intl/intl.dart';
import 'package:mezzome/core/l10n/weekday_labels.dart';

/// Date helpers for production plan queries (`YYYY-MM-DD`).
abstract final class DateFormatUtil {
  /// Calendar "today" from device clock (date only).
  static DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static int get currentYear => DateTime.now().year;

  /// Schedule UI/API dates always use [currentYear] (month/day from [date]).
  static DateTime normalizeScheduleDate(DateTime date) {
    final year = currentYear;
    final month = date.month.clamp(1, 12);
    return clampDayInMonth(date, year, month);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) => isSameDay(date, today);

  /// Localized weekday + day + month (e.g. «среда, 3 июня»).
  /// Дата+время для логов/метаданных: «04.06.2026 14:42» (локальное время).
  static String formatDateTimeShort(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
  }

  static String formatDisplayDate(DateTime date, String locale) {
    final local = DateTime(date.year, date.month, date.day);
    return DateFormat('EEEE, d MMMM', locale).format(local);
  }

  /// Месяц + год, e.g. «Июнь 2026» (для шапки ленты дат в режиме «День»).
  static String formatMonthYear(DateTime date, String locale) {
    final s = DateFormat('LLLL yyyy', locale).format(date);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  /// Short weekday + day + month + year (e.g. «Чт, 22 июня 2026 года»).
  static String formatScheduleDateLong(DateTime date, String locale) {
    final local = DateTime(date.year, date.month, date.day);
    final weekday = localizedWeekdayLabels()[local.weekday - DateTime.monday];
    final dayMonth = DateFormat('d MMMM', locale).format(local);
    final year = local.year;
    final lang = locale.split('_').first.split('-').first;

    return switch (lang) {
      'ru' => '$weekday, $dayMonth $year года',
      'kk' => '$weekday, $dayMonth $year ж.',
      _ => '$weekday, $dayMonth $year',
    };
  }

  /// Диапазон недели для шапки: «1–7 июня 2026» или «29 июня – 5 июля 2026».
  static String formatWeekRange(DateTime weekStart, String locale) {
    final start = startOfWeek(weekStart);
    final end = start.add(const Duration(days: 6));
    final sameMonth = start.month == end.month && start.year == end.year;
    final endPart = DateFormat('d MMMM', locale).format(end);
    final year = end.year;
    if (sameMonth) {
      final startDay = start.day;
      return '$startDay–$endPart $year';
    }
    final startPart = DateFormat('d MMMM', locale).format(start);
    return '$startPart – $endPart $year';
  }

  static String apiDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Monday of the week containing [date].
  static DateTime startOfWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static List<DateTime> weekDaysFrom(DateTime anchor) {
    final start = startOfWeek(anchor);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  /// All calendar days in the month of [anchor].
  static List<DateTime> daysInMonth(DateTime anchor) {
    final year = anchor.year;
    final month = anchor.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    return List.generate(
      lastDay,
      (i) => DateTime(year, month, i + 1),
    );
  }

  static DateTime clampDayInMonth(DateTime date, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day.clamp(1, lastDay);
    return DateTime(year, month, day);
  }
}

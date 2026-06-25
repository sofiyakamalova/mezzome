import 'package:easy_localization/easy_localization.dart';

enum MenuServiceType {
  breakfast,
  lunch,
  dinner,
  nightLunch;

  String get labelKey => switch (this) {
        MenuServiceType.breakfast => 'serviceBreakfast',
        MenuServiceType.lunch => 'serviceLunch',
        MenuServiceType.dinner => 'serviceDinner',
        MenuServiceType.nightLunch => 'serviceNightLunch',
      };

  String get label => labelKey.tr();

  /// Query param for `GET .../production-plans?service_type=`.
  /// Ночной обед на бэке — `night_lunch` (snake_case), остальные = имя enum.
  String get apiValue =>
      this == MenuServiceType.nightLunch ? 'night_lunch' : name;

  /// Values from production plan `service_type` (case-insensitive match).
  bool matchesApiValue(String? value) {
    if (value == null || value.trim().isEmpty || value == '—') {
      return this == MenuServiceType.lunch;
    }
    final normalized = value.toLowerCase();
    final isNight =
        normalized.contains('night') || normalized.contains('ноч');
    return switch (this) {
      MenuServiceType.breakfast =>
        normalized.contains('breakfast') || normalized.contains('завтрак'),
      // Обычный обед — но НЕ «ночной обед» (night_lunch).
      MenuServiceType.lunch =>
        (normalized.contains('lunch') || normalized.contains('обед')) &&
            !isNight,
      MenuServiceType.dinner =>
        normalized.contains('dinner') || normalized.contains('ужин'),
      MenuServiceType.nightLunch =>
        normalized.contains('night_lunch') ||
            (isNight &&
                (normalized.contains('lunch') || normalized.contains('обед'))),
    };
  }
}

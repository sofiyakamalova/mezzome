import 'package:easy_localization/easy_localization.dart';

enum MenuServiceType {
  breakfast,
  lunch,
  dinner;

  String get labelKey => switch (this) {
        MenuServiceType.breakfast => 'serviceBreakfast',
        MenuServiceType.lunch => 'serviceLunch',
        MenuServiceType.dinner => 'serviceDinner',
      };

  String get label => labelKey.tr();

  /// Query param for `GET .../production-plans?service_type=`.
  String get apiValue => name;

  /// Values from production plan `service_type` (case-insensitive match).
  bool matchesApiValue(String? value) {
    if (value == null || value.trim().isEmpty || value == '—') {
      return this == MenuServiceType.lunch;
    }
    final normalized = value.toLowerCase();
    return switch (this) {
      MenuServiceType.breakfast =>
        normalized.contains('breakfast') || normalized.contains('завтрак'),
      MenuServiceType.lunch =>
        normalized.contains('lunch') || normalized.contains('обед'),
      MenuServiceType.dinner =>
        normalized.contains('dinner') || normalized.contains('ужин'),
    };
  }
}

/// 8px grid (§11 ТЗ).
abstract final class AppSpacing {
  static const double unit = 8;

  static const double xxs = unit * 0.5; // 4
  static const double xs = unit; // 8
  static const double sm = unit * 2; // 16
  static const double md = unit * 3; // 24
  static const double lg = unit * 4; // 32
  static const double xl = unit * 5; // 40

  /// Поля ввода и небольшие элементы.
  static const double radiusSm = 10;

  /// Карточки и крупные контейнеры.
  static const double radiusMd = 14;

  /// CTA-кнопки.
  static const double radiusButton = 12;

  /// Бейджи / пилюли (статусы, роли) — скруглённые, максимум 16 (без «таблеток»).
  static const double radiusPill = 16;
}

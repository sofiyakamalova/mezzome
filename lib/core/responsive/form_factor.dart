import 'package:flutter/widgets.dart';

/// Класс размера окна (Material 3 window size classes).
///
/// ВАЖНО: ориентируемся на ШИРИНУ окна, а НЕ на платформу (`kIsWeb`/`Platform`):
/// веб открывают и с телефона, приложение ставят и на планшет. Платформу проверяем
/// отдельно и только для поведения (диплинки, скачивание, hover), не для верстки.
enum FormFactor { compact, medium, expanded }

/// Брейкпоинты Material 3 (width breakpoints).
abstract final class Breakpoints {
  /// < 600 — телефон (compact); 600–1024 — планшет (medium); > 1024 — десктоп/веб (expanded).
  static const double medium = 600;
  static const double expanded = 1024;
}

FormFactor formFactorForWidth(double width) {
  if (width >= Breakpoints.expanded) return FormFactor.expanded;
  if (width >= Breakpoints.medium) return FormFactor.medium;
  return FormFactor.compact;
}

extension ResponsiveContext on BuildContext {
  /// Форм-фактор по ширине всего окна.
  FormFactor get formFactor =>
      formFactorForWidth(MediaQuery.sizeOf(this).width);

  bool get isCompact => formFactor == FormFactor.compact;
  bool get isMedium => formFactor == FormFactor.medium;

  /// Десктоп/широкий веб — «двухколоночные» макеты.
  bool get isExpanded => formFactor == FormFactor.expanded;
}

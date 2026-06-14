import 'package:intl/intl.dart';

/// Деньги в тенге: целые, с разделением разрядов («1 250 000 ₸»).
String formatTenge(double value) {
  final n = NumberFormat.decimalPattern('ru').format(value.round());
  return '$n ₸';
}

/// Деньги со знаком (для прибыли/отклонений): «+12 000 ₸» / «−3 400 ₸».
String formatSignedTenge(double value) {
  final n = NumberFormat.decimalPattern('ru').format(value.abs().round());
  final sign = value < 0 ? '−' : '+';
  return '$sign$n ₸';
}

/// Проценты: одно-два знака после запятой («23.5%»).
String formatPercent(double value, {int digits = 1}) {
  return '${value.toStringAsFixed(digits)}%';
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';

/// Тема приложения (get_it singleton). По умолчанию — светлая; выбор персистится
/// в SharedPreferences.
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    emit(_fromStorage(prefs.getString(_themeModeKey)));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _toStorage(mode));
    appLogger.i('Theme mode → ${_toStorage(mode)}');
  }

  // По умолчанию (нет сохранённого выбора) — светлая тема.
  static ThemeMode _fromStorage(String? value) => switch (value) {
        'dark' => ThemeMode.dark,
        _ => ThemeMode.light,
      };

  static String _toStorage(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'dark',
      };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _fromStorage(prefs.getString(_themeModeKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
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

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

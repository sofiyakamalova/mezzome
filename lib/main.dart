import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mezzome/app.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/l10n/app_locales.dart';
import 'package:mezzome/core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.i('MEZZOME Kitchen OS starting');
  await EasyLocalization.ensureInitialized();
  await configureDependencies();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      path: 'assets/translations',
      fallbackLocale: AppLocales.fallback,
      startLocale: AppLocales.fallback,
      saveLocale: true,
      useOnlyLangCode: true,
      useFallbackTranslations: true,
      child: const MezzomeApp(),
    ),
  );
}

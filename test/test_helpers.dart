import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezzome/core/l10n/app_locales.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> setupLocalizationTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

Widget wrapWithLocalization(Widget child) {
  return EasyLocalization(
    key: UniqueKey(),
    supportedLocales: AppLocales.supported,
    path: 'assets/translations',
    fallbackLocale: AppLocales.fallback,
    startLocale: AppLocales.fallback,
    useOnlyLangCode: true,
    child: child,
  );
}

Widget wrapMaterialApp(
  Widget home, {
  List<Override> overrides = const [],
}) {
  return wrapWithLocalization(
    Builder(
      builder: (context) => ProviderScope(
        key: UniqueKey(),
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: home,
        ),
      ),
    ),
  );
}

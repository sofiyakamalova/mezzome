import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/router/app_router.dart';
import 'package:mezzome/core/theme/app_theme.dart';
import 'package:mezzome/core/theme/theme_mode_provider.dart';

class MezzomeApp extends ConsumerWidget {
  const MezzomeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.light;

    return MaterialApp.router(
      title: 'appTitle'.tr(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
    );
  }
}

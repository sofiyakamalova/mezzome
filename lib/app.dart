import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/theme/app_theme.dart';
import 'package:mezzome/core/theme/theme_mode_cubit.dart';

class MezzomeApp extends StatelessWidget {
  const MezzomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeModeCubit, ThemeMode>(
      bloc: sl<ThemeModeCubit>(),
      builder: (context, themeMode) => MaterialApp.router(
        title: 'appTitle'.tr(),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        routerConfig: sl<GoRouter>(),
      ),
    );
  }
}

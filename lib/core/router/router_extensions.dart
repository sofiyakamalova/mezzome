import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mezzome/core/router/app_routes.dart';

extension MezzomeRouter on BuildContext {
  void goToLogin() => goNamed(AppRoutes.loginName);

  void goToDashboard() => goNamed(AppRoutes.dashboardName);

  void goToDishes() => goNamed(AppRoutes.dishesName);

  void goToSettings() => goNamed(AppRoutes.settingsName);
}

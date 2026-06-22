import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/rbac/permissions.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';

/// Persistent bottom tab bar for authenticated main flows.
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const int dashboardBranch = 0;
  static const int settingsBranch = 1;
  static const int dishesBranch = 2;
  static const int approvalsBranch = 3;
  static const int myRequestsBranch = 4;
  static const int createPlanBranch = 5;
  static const int expensesBranch = 6;
  static const int techCardsBranch = 7;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthSessionCubit, AuthSessionState>(
      bloc: sl<AuthSessionCubit>(),
      builder: (context, session) => _buildShell(context, session.role),
    );
  }

  Widget _buildShell(BuildContext context, UserRole? role) {
    final isManager = role != null && usesDirectorShell(role);

    // Manager (директор): дашборд · таблица блюд · план на неделю ·
    // согласования техкарт · настройки.
    // Chef: таблица блюд (видит план, правит техкарту) · мои запросы · настройки.
    final items = isManager
        ? [
            _BarItem(
              branch: dashboardBranch,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'navDashboard'.tr(),
            ),
            _BarItem(
              branch: expensesBranch,
              icon: Icons.insights_outlined,
              activeIcon: Icons.insights,
              label: 'navFinance'.tr(),
            ),
            _BarItem(
              branch: dishesBranch,
              icon: Icons.restaurant_menu_outlined,
              activeIcon: Icons.restaurant_menu,
              label: 'navMenu'.tr(),
            ),
            // Составление плана на неделю — у директора.
            _BarItem(
              branch: createPlanBranch,
              icon: Icons.edit_calendar_outlined,
              activeIcon: Icons.edit_calendar,
              label: 'navCreatePlan'.tr(),
            ),
            _BarItem(
              branch: approvalsBranch,
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check,
              label: 'navApprovals'.tr(),
            ),
            _BarItem(
              branch: settingsBranch,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'navSettings'.tr(),
            ),
          ]
        : [
            _BarItem(
              branch: dishesBranch,
              icon: Icons.restaurant_menu_outlined,
              activeIcon: Icons.restaurant_menu,
              label: 'navMenu'.tr(),
            ),
            _BarItem(
              branch: techCardsBranch,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book,
              label: 'navTechCards'.tr(),
            ),
            _BarItem(
              branch: myRequestsBranch,
              icon: Icons.send_outlined,
              activeIcon: Icons.send,
              label: 'navMyRequests'.tr(),
            ),
            _BarItem(
              branch: settingsBranch,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'navSettings'.tr(),
            ),
          ];

    final shellIndex = navigationShell.currentIndex;
    final barIndex = items.indexWhere((item) => item.branch == shellIndex);
    final selectedIndex = barIndex < 0 ? 0 : barIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          final branch = items[index].branch;
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        items: items
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BarItem {
  const _BarItem({
    required this.branch,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

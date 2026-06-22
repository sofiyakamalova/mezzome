import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/constants/app_colors_light.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/l10n/app_locales.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/core/router/router_extensions.dart';
import 'package:mezzome/core/theme/theme_mode_cubit.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';
import 'package:mezzome/features/inventory/presentation/create_ingredient_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthSessionCubit, AuthSessionState>(
      bloc: sl<AuthSessionCubit>(),
      builder: (context, session) => _build(context, session),
    );
  }

  Widget _build(BuildContext context, AuthSessionState session) {
    final user = session.user;
    final role = user?.role;
    // Создание ингредиента — только owner/admin (бэк: POST /owner/inventory;
    // менеджеру → 403 FORBIDDEN).
    final canManageInventory =
        role == UserRole.owner || role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text('settingsTitle'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Профиль
          if (session.isLoading)
            const _CardBox(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (user != null)
            _ProfileCard(user: user),
          const SizedBox(height: AppSpacing.lg),

          // Управление (создание ингредиента) — owner/admin/manager.
          if (canManageInventory) ...[
            _SectionHeader(title: 'settingsManageSection'.tr()),
            _CardBox(
              child: ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: Text('ingCreateTitle'.tr()),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => CreateIngredientScreen.open(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Язык
          _SectionHeader(title: 'settingsLanguageSection'.tr()),
          _CardBox(
            child: Column(
              children: [
                for (var i = 0; i < AppLocales.supported.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: ThemePalette.border(context),
                    ),
                  _LanguageTile(
                    locale: AppLocales.supported[i],
                    selected:
                        context.locale.languageCode ==
                        AppLocales.supported[i].languageCode,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Тема
          _SectionHeader(title: 'settingsThemeSection'.tr()),
          _CardBox(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: BlocBuilder<ThemeModeCubit, ThemeMode>(
                bloc: sl<ThemeModeCubit>(),
                builder: (context, themeMode) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_outlined, size: 18),
                        label: Text('themeLight'.tr()),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text('themeDark'.tr()),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) =>
                        sl<ThemeModeCubit>().setThemeMode(selection.first),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Выход
          if (user != null)
            OutlinedButton.icon(
              onPressed: () async {
                await sl<AuthSessionCubit>().logout();
                if (context.mounted) {
                  context.goToLogin();
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text('logoutTooltip'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerRed,
                side: const BorderSide(color: AppColors.dangerRed),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
        ],
      ),
    );
  }
}

/// Карточка профиля: аватар-инициалы, имя, телефон, пилюля роли.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final UserModel user;

  String get _initials {
    final parts = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = ThemePalette.isLight(context);
    final avatarBg = isLight
        ? AppColorsLight.accentSoft
        : AppColors.surfaceElevated;
    final avatarFg = ThemePalette.accent(context);

    return _CardBox(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: avatarFg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.phone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ThemePalette.onSurfaceMuted(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _RolePill(label: _roleLabel(user.role)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пилюля роли — мягкая синяя заливка с тёмно-синим текстом.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isLight = ThemePalette.isLight(context);
    final bg = isLight
        ? AppColorsLight.accentSoft
        : ThemePalette.accent(context).withValues(alpha: 0.16);
    final fg = isLight
        ? AppColorsLight.onAccentSoft
        : ThemePalette.accent(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String _roleLabel(UserRole role) => switch (role) {
  UserRole.owner => 'roleOwner'.tr(),
  UserRole.supervisor => 'roleSupervisor'.tr(),
  UserRole.manager => 'roleManager'.tr(),
  UserRole.chef => 'roleChef'.tr(),
  UserRole.hotCook => 'roleHotCook'.tr(),
  UserRole.coldCook => 'roleColdCook'.tr(),
  UserRole.prepCook => 'rolePrepCook'.tr(),
  UserRole.butcher => 'roleButcher'.tr(),
  UserRole.storekeeper => 'roleStorekeeper'.tr(),
  UserRole.waiter => 'roleWaiter'.tr(),
  UserRole.admin => 'roleAdmin'.tr(),
  UserRole.runner => 'roleRunner'.tr(),
  UserRole.client => 'roleClient'.tr(),
  UserRole.unknown => role.apiValue,
};

/// Контейнер-карточка с единым скруглением/границей светлой темы.
class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ThemePalette.surfaceCard(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ThemePalette.border(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: ThemePalette.onSurfaceMuted(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.locale, required this.selected});

  final Locale locale;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = ThemePalette.accent(context);
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ThemePalette.isLight(context)
              ? AppColorsLight.surfaceSecondary
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(
          locale.languageCode.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ThemePalette.onSurfaceMuted(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      title: Text(_label(locale)),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: accent, size: 20)
          : null,
      onTap: selected
          ? null
          : () {
              appLogger.i('Locale changed → ${locale.languageCode}');
              context.setLocale(locale);
            },
    );
  }

  String _label(Locale locale) => switch (locale.languageCode) {
    'ru' => 'languageRu'.tr(),
    'kk' => 'languageKk'.tr(),
    'en' => 'languageEn'.tr(),
    _ => locale.languageCode,
  };
}

import 'package:mezzome/domain/user_role.dart';

/// RBAC helpers (§3 ТЗ). Final check — on server (403).
///
/// Приложение сейчас рассчитано только на две роли: `manager` (директор) и
/// `chef`. Прочие значения [UserRole] оставлены в enum (зеркалят серверный
/// `domain.Role`), но в UI/навигации не используются.
bool canSeeFinancials(UserRole role) =>
    role == UserRole.manager || role == UserRole.chef;

/// Роль с доступом к owner-эндпоинтам данных (owner menu-items и т.п.).
/// В двухролевой модели (manager + chef) таких нет — для обеих ролей это
/// `false`, поэтому они ходят на common-ручки. Оставлена как селектор
/// эндпоинтов; навигацию определяет [usesDirectorShell].
bool canOpenDirectorDashboard(UserRole role) =>
    role == UserRole.owner ||
    role == UserRole.supervisor ||
    role == UserRole.admin;

/// Директорская навигация (дашборд · меню · план · согласования · настройки)
/// и старт на дашборде — это роль `manager`. Chef стартует на таблице блюд.
bool usesDirectorShell(UserRole role) => role == UserRole.manager;

/// Кухонный персонал — для выбора chef-эндпоинтов планов. В текущей модели
/// это только `chef`.
bool isKitchenStaff(UserRole role) => role == UserRole.chef;

import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';

/// Мост текущей сессии в get_it: хранит активного пользователя.
/// Источник истины — `authSessionProvider` (Riverpod); MezzomeApp синхронизирует
/// сюда юзера при изменении сессии. Нужен сервисам/репозиториям/BLoC в get_it,
/// которым требуется роль/имя, но недоступен Riverpod Ref.
class SessionHolder {
  UserModel? user;

  UserRole? get role => user?.role;
}

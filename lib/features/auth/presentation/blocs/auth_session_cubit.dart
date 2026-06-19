import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/di/session_holder.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/features/auth/data/repository/auth_repository.dart';

part 'auth_session_state.dart';

/// Текущая сессия (get_it singleton). Источник истины о пользователе/роли;
/// синхронизирует [SessionHolder], который читают сервисы/репозитории в get_it.
class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit(this._repo, this._holder)
      : super(const AuthSessionState(AuthStatus.loading)) {
    restore();
  }

  final AuthRepository _repo;
  final SessionHolder _holder;

  /// Восстановить сессию из хранилища токенов (вызывается на старте).
  Future<void> restore() async {
    emit(const AuthSessionState(AuthStatus.loading));
    final user = await _repo.getCurrentUser();
    if (user != null) {
      appLogger.i('Session restored: ${user.name} (${user.role.apiValue})');
    } else {
      appLogger.i('No active session');
    }
    _set(user);
  }

  /// Перечитать сессию после входа.
  Future<void> refresh() {
    appLogger.i('Refreshing auth session');
    return restore();
  }

  Future<void> logout() async {
    appLogger.i('Auth session logout');
    await _repo.logout();
    _set(null);
  }

  void _set(UserModel? user) {
    _holder.user = user; // мост в get_it для сервисов/репозиториев
    emit(AuthSessionState(
      user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      user,
    ));
  }
}

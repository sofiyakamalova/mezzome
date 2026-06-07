import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/domain/user_role.dart';
import 'package:mezzome/features/auth/data/models/user_model.dart';
import 'package:mezzome/features/auth/data/repository/auth_repository.dart';
import 'package:mezzome/features/auth/presentation/providers/login_notifier.dart';

/// Current session: `null` when logged out.
class AuthSessionNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    final user = await ref.read(authRepositoryProvider).getCurrentUser();
    if (user != null) {
      appLogger.i(
        'Session restored: ${user.name} (${user.role.apiValue})',
      );
    } else {
      appLogger.i('No active session');
    }
    return user;
  }

  Future<void> refresh() async {
    appLogger.i('Refreshing auth session');
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).getCurrentUser(),
    );
  }

  Future<void> logout() async {
    appLogger.i('Auth session logout');
    await ref.read(authRepositoryProvider).logout();
    // Сбрасываем форму логина к шагу ввода номера (иначе откроется OTP).
    ref.invalidate(loginNotifierProvider);
    state = const AsyncData(null);
  }
}

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, UserModel?>(
  AuthSessionNotifier.new,
);

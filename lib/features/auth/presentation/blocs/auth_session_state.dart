part of 'auth_session_cubit.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthSessionState {
  const AuthSessionState(this.status, [this.user]);

  final AuthStatus status;
  final UserModel? user;

  UserRole? get role => user?.role;
  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
}

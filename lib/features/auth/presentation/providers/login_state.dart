enum LoginStep { phone, otp }

class LoginState {
  const LoginState({
    this.step = LoginStep.phone,
    this.phone = '+7 ',
    this.otp = '',
    this.isLoading = false,
    this.errorMessage,
    this.usedDevClientRegistration = false,
  });

  final LoginStep step;
  final String phone;
  final String otp;
  final bool isLoading;
  final String? errorMessage;
  final bool usedDevClientRegistration;

  LoginState copyWith({
    LoginStep? step,
    String? phone,
    String? otp,
    bool? isLoading,
    String? errorMessage,
    bool? usedDevClientRegistration,
    bool clearError = false,
  }) {
    return LoginState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      otp: otp ?? this.otp,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      usedDevClientRegistration:
          usedDevClientRegistration ?? this.usedDevClientRegistration,
    );
  }
}

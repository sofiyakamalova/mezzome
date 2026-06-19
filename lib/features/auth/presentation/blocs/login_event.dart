part of 'login_bloc.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginPhoneChanged extends LoginEvent {
  const LoginPhoneChanged(this.phone);

  final String phone;

  @override
  List<Object?> get props => [phone];
}

class LoginOtpChanged extends LoginEvent {
  const LoginOtpChanged(this.otp);

  final String otp;

  @override
  List<Object?> get props => [otp];
}

class LoginOtpRequested extends LoginEvent {
  const LoginOtpRequested();
}

class LoginVerifySubmitted extends LoginEvent {
  const LoginVerifySubmitted();
}

class LoginBackToPhone extends LoginEvent {
  const LoginBackToPhone();
}

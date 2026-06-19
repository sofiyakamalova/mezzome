import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/auth/domain/phone_utils.dart';
import 'package:mezzome/features/auth/domain/use_cases/send_login_otp_use_case.dart';
import 'package:mezzome/features/auth/domain/use_cases/verify_login_otp_use_case.dart';

part 'login_event.dart';
part 'login_state.dart';

/// BLoC входа по телефону (OTP). Зависит только от domain (use_cases).
/// После успешной проверки кода ставит `verified=true` — экран реагирует и
/// перезагружает сессию (authSessionProvider остаётся на Riverpod до миграции).
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({
    required SendLoginOtpUseCase sendOtp,
    required VerifyLoginOtpUseCase verifyOtp,
  })  : _sendOtp = sendOtp,
        _verifyOtp = verifyOtp,
        super(const LoginState()) {
    on<LoginPhoneChanged>(
      (e, emit) => emit(state.copyWith(phone: e.phone, clearError: true)),
    );
    on<LoginOtpChanged>(
      (e, emit) => emit(state.copyWith(otp: e.otp, clearError: true)),
    );
    on<LoginOtpRequested>(_onSend);
    on<LoginVerifySubmitted>(_onVerify);
    on<LoginBackToPhone>(
      (e, emit) => emit(state.copyWith(
        step: LoginStep.phone,
        otp: '',
        clearError: true,
        usedDevClientRegistration: false,
      )),
    );
  }

  final SendLoginOtpUseCase _sendOtp;
  final VerifyLoginOtpUseCase _verifyOtp;

  Future<void> _onSend(LoginOtpRequested e, Emitter<LoginState> emit) async {
    if (!isValidPhone(state.phone)) {
      emit(state.copyWith(errorMessage: 'errorInvalidPhone'.tr()));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final devReg = await _sendOtp(state.phone);
      emit(state.copyWith(
        step: LoginStep.otp,
        isLoading: false,
        otp: '',
        usedDevClientRegistration: devReg,
      ));
    } on DioException catch (error) {
      appLogger.e('sendOtp failed', error: error);
      emit(state.copyWith(isLoading: false, errorMessage: _mapError(error)));
    } catch (e, st) {
      appLogger.e('sendOtp failed', error: e, stackTrace: st);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'errorSendOtpFailed'.tr(),
      ));
    }
  }

  Future<void> _onVerify(
    LoginVerifySubmitted e,
    Emitter<LoginState> emit,
  ) async {
    final code = state.otp.trim();
    if (code.length != 6) {
      emit(state.copyWith(errorMessage: 'errorOtpLength'.tr()));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _verifyOtp(phone: state.phone, otp: code);
      appLogger.i('OTP verified');
      emit(state.copyWith(isLoading: false, verified: true));
    } on DioException catch (error) {
      appLogger.e('verifyOtp failed', error: error);
      emit(state.copyWith(isLoading: false, errorMessage: _mapError(error)));
    } catch (e, st) {
      appLogger.e('verifyOtp failed', error: e, stackTrace: st);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'errorVerifyFailed'.tr(),
      ));
    }
  }

  String _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final code = data['error'];
      final details = data['details'];
      final message = data['message'];

      if (code == 'USER_NOT_FOUND') return 'errorUserNotFound'.tr();

      if (code == 'INVALID_OTP') {
        final devHint = kDebugMode ? 'errorInvalidOtpDevHint'.tr() : '';
        return 'errorInvalidOtp'.tr(
              namedArgs: {'details': details is String ? ' $details' : ''},
            ) +
            devHint;
      }
      if (message is String && message.isNotEmpty) return message;
      if (code is String && code.isNotEmpty) {
        return details is String ? '$code: $details' : code;
      }
    }
    final status =
        error.response?.statusCode?.toString() ?? 'errorNoConnection'.tr();
    return 'errorNetwork'.tr(namedArgs: {'status': status});
  }
}

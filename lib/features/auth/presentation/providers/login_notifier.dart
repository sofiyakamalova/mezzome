import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/logging/app_logger.dart';
import 'package:mezzome/features/auth/data/repository/auth_repository.dart';
import 'package:mezzome/features/auth/domain/phone_utils.dart';
import 'package:mezzome/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:mezzome/features/auth/presentation/providers/login_state.dart';

class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void updatePhone(String value) {
    state = state.copyWith(phone: value, clearError: true);
  }

  void updateOtp(String value) {
    state = state.copyWith(otp: value, clearError: true);
  }

  Future<void> sendOtp() async {
    if (!isValidPhone(state.phone)) {
      state = state.copyWith(errorMessage: 'errorInvalidPhone'.tr());
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final usedDevRegistration = await ref
          .read(authRepositoryProvider)
          .sendOtpForLogin(state.phone);
      appLogger.i(
        'OTP sent, step=otp devRegistration=$usedDevRegistration',
      );
      state = state.copyWith(
        step: LoginStep.otp,
        isLoading: false,
        otp: '',
        usedDevClientRegistration: usedDevRegistration,
      );
    } on DioException catch (error) {
      appLogger.e('sendOtp failed', error: error);
      state = state.copyWith(isLoading: false, errorMessage: _mapError(error));
    } catch (e, st) {
      appLogger.e('sendOtp failed', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'errorSendOtpFailed'.tr(),
      );
    }
  }

  Future<bool> verifyOtp() async {
    final code = state.otp.trim();
    if (code.length != 6) {
      state = state.copyWith(errorMessage: 'errorOtpLength'.tr());
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: state.phone, otp: code);
      appLogger.i('OTP verified, session invalidated for reload');
      ref.invalidate(authSessionProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (error) {
      appLogger.e('verifyOtp failed', error: error);
      state = state.copyWith(isLoading: false, errorMessage: _mapError(error));
      return false;
    } catch (e, st) {
      appLogger.e('verifyOtp failed', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'errorVerifyFailed'.tr(),
      );
      return false;
    }
  }

  void backToPhone() {
    state = state.copyWith(
      step: LoginStep.phone,
      otp: '',
      clearError: true,
      usedDevClientRegistration: false,
    );
  }

  String _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final code = data['error'];
      final details = data['details'];
      final message = data['message'];

      if (code == 'USER_NOT_FOUND') {
        return 'errorUserNotFound'.tr();
      }

      if (code == 'INVALID_OTP') {
        final devHint = kDebugMode ? 'errorInvalidOtpDevHint'.tr() : '';
        return 'errorInvalidOtp'.tr(
          namedArgs: {
            'details': details is String ? ' $details' : '',
          },
        ) + devHint;
      }

      if (message is String && message.isNotEmpty) {
        return message;
      }

      if (code is String && code.isNotEmpty) {
        return details is String ? '$code: $details' : code;
      }
    }

    final status = error.response?.statusCode?.toString() ??
        'errorNoConnection'.tr();
    return 'errorNetwork'.tr(namedArgs: {'status': status});
  }
}

final loginNotifierProvider = NotifierProvider<LoginNotifier, LoginState>(
  LoginNotifier.new,
);

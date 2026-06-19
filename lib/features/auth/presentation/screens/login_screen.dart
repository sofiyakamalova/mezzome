import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/di/locator.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/l10n/language_picker.dart';
import 'package:mezzome/features/auth/domain/kazakhstan_phone_mask_formatter.dart';
import 'package:mezzome/features/auth/domain/phone_utils.dart';
import 'package:mezzome/features/auth/presentation/blocs/auth_session_cubit.dart';
import 'package:mezzome/features/auth/presentation/blocs/login_bloc.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.bloc});

  /// Для тестов: подменить bloc. В проде создаётся из get_it.
  final LoginBloc? bloc;

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(value: bloc!, child: const _LoginView());
    }
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: KazakhstanPhoneMask.prefix);
    _otpController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onSendOtp() {
    FocusScope.of(context).unfocus();
    context.read<LoginBloc>().add(const LoginOtpRequested());
  }

  void _onVerifyOtp() {
    FocusScope.of(context).unfocus();
    context.read<LoginBloc>().add(const LoginVerifySubmitted());
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LoginBloc>();
    return Scaffold(
      appBar: AppBar(actions: const [LanguagePicker()]),
      body: SafeArea(
        child: BlocConsumer<LoginBloc, LoginState>(
          listenWhen: (p, n) =>
              p.verified != n.verified ||
              p.phone != n.phone ||
              p.otp != n.otp,
          listener: (context, state) {
            // Успешный вход → перезагрузить сессию (роутер уведёт с логина).
            if (state.verified) {
              sl<AuthSessionCubit>().refresh();
            }
            if (_phoneController.text != state.phone) {
              _phoneController.text = state.phone;
            }
            if (_otpController.text != state.otp) {
              _otpController.text = state.otp;
            }
          },
          builder: (context, state) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'MEZZOME',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: ThemePalette.accent(context)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'kitchenOs'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        state.step == LoginStep.phone
                            ? 'loginPhoneTitle'.tr()
                            : 'loginOtpTitle'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (state.step == LoginStep.phone) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'phoneLabel'.tr(),
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          inputFormatters: [
                            KazakhstanPhoneMaskFormatter(),
                            LengthLimitingTextInputFormatter(
                              KazakhstanPhoneMask.maxFormattedLength,
                            ),
                          ],
                          onChanged: (v) =>
                              bloc.add(LoginPhoneChanged(v)),
                          onSubmitted: (_) => _onSendOtp(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PrimaryButton(
                          label: 'getCodeButton'.tr(),
                          isLoading: state.isLoading,
                          onPressed: state.isLoading ? null : _onSendOtp,
                        ),
                      ] else ...[
                        Text(
                          'otpSentTo'.tr(
                            namedArgs: {
                              'phone': formatPhoneForDisplay(
                                normalizePhone(state.phone),
                              ),
                            },
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'otpLabel'.tr(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            counterText: '',
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) => bloc.add(LoginOtpChanged(v)),
                          onSubmitted: (_) => _onVerifyOtp(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PrimaryButton(
                          label: 'signInButton'.tr(),
                          isLoading: state.isLoading,
                          onPressed: state.isLoading ? null : _onVerifyOtp,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: state.isLoading
                              ? null
                              : () => bloc.add(const LoginBackToPhone()),
                          child: Text('changePhoneButton'.tr()),
                        ),
                        TextButton(
                          onPressed: state.isLoading ? null : _onSendOtp,
                          child: Text('resendCodeButton'.tr()),
                        ),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          state.errorMessage!,
                          style: const TextStyle(color: AppColors.dangerRed),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

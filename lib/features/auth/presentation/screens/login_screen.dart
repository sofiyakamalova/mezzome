import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezzome/core/constants/app_colors.dart';
import 'package:mezzome/core/theme/theme_palette.dart';
import 'package:mezzome/core/constants/app_spacing.dart';
import 'package:mezzome/core/l10n/language_picker.dart';
import 'package:mezzome/features/auth/domain/kazakhstan_phone_mask_formatter.dart';
import 'package:mezzome/features/auth/domain/phone_utils.dart';
import 'package:mezzome/features/auth/presentation/providers/login_notifier.dart';
import 'package:mezzome/features/auth/presentation/providers/login_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: KazakhstanPhoneMask.prefix,
    );
    _otpController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginNotifierProvider);
    final notifier = ref.read(loginNotifierProvider.notifier);

    ref.listen(loginNotifierProvider, (previous, next) {
      if (previous?.phone != next.phone &&
          _phoneController.text != next.phone) {
        _phoneController.text = next.phone;
      }
      if (previous?.otp != next.otp && _otpController.text != next.otp) {
        _otpController.text = next.otp;
      }
    });

    return Scaffold(
      appBar: AppBar(
        actions: const [LanguagePicker()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'MEZZOME',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: ThemePalette.accent(context),
                    ),
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
                    loginState.step == LoginStep.phone
                        ? 'loginPhoneTitle'.tr()
                        : 'loginOtpTitle'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (loginState.step == LoginStep.phone) ...[
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
                      onChanged: notifier.updatePhone,
                      onSubmitted: (_) => _onSendOtp(notifier),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PrimaryButton(
                      label: 'getCodeButton'.tr(),
                      isLoading: loginState.isLoading,
                      onPressed: loginState.isLoading
                          ? null
                          : () => _onSendOtp(notifier),
                    ),
                  ] else ...[
                    Text(
                      'otpSentTo'.tr(
                        namedArgs: {
                          'phone': formatPhoneForDisplay(
                            normalizePhone(loginState.phone),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: notifier.updateOtp,
                      onSubmitted: (_) => _onVerifyOtp(notifier),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PrimaryButton(
                      label: 'signInButton'.tr(),
                      isLoading: loginState.isLoading,
                      onPressed: loginState.isLoading
                          ? null
                          : () => _onVerifyOtp(notifier),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: loginState.isLoading
                          ? null
                          : notifier.backToPhone,
                      child: Text('changePhoneButton'.tr()),
                    ),
                    TextButton(
                      onPressed: loginState.isLoading
                          ? null
                          : () => _onSendOtp(notifier),
                      child: Text('resendCodeButton'.tr()),
                    ),
                  ],
                  if (loginState.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      loginState.errorMessage!,
                      style: const TextStyle(color: AppColors.dangerRed),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSendOtp(LoginNotifier notifier) async {
    FocusScope.of(context).unfocus();
    await notifier.sendOtp();
  }

  Future<void> _onVerifyOtp(LoginNotifier notifier) async {
    FocusScope.of(context).unfocus();
    await notifier.verifyOtp();
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

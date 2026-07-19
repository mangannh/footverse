import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../models/verify_reset_otp_request.dart';
import '../providers/password_reset_provider.dart';
import '../validators/auth_validators.dart';
import '../widgets/reset_step_indicator.dart';

/// Step 2 of the password-reset flow: verify the emailed one-time code and
/// obtain the opaque reset token (sprint-13-plan Task 07).
///
/// It reuses the **same** [PasswordResetProvider] instance created by
/// [ForgotPasswordScreen] (passed in, never created here — Design Note) and
/// passes it forward again to [AppRoute.resetPassword] on success. "Resend
/// code" deliberately does **not** re-request an OTP from this screen; it
/// returns to step one so the user can resubmit their email, matching the
/// frozen server flow (a fresh code always starts from `forgot-password`).
class VerifyResetOtpScreen extends StatelessWidget {
  const VerifyResetOtpScreen({
    required this.provider,
    required this.email,
    super.key,
  });

  /// The single provider instance created at step one.
  final PasswordResetProvider provider;

  /// The email submitted at step one, carried forward for the verify request
  /// and, on success, the next step's navigation.
  final String email;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PasswordResetProvider>.value(
      value: provider,
      child: _VerifyResetOtpView(email: email),
    );
  }
}

class _VerifyResetOtpView extends StatefulWidget {
  const _VerifyResetOtpView({required this.email});

  final String email;

  @override
  State<_VerifyResetOtpView> createState() => _VerifyResetOtpViewState();
}

class _VerifyResetOtpViewState extends State<_VerifyResetOtpView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final provider = context.read<PasswordResetProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await provider.verifyOtp(
        VerifyResetOtpRequest(
          email: widget.email,
          otp: _otpController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      router.goNamed(AppRoute.resetPassword, extra: (provider, widget.email));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _resend() {
    GoRouter.of(context).goNamed(AppRoute.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.watch<PasswordResetProvider>().status ==
        PasswordResetStatus.loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify code')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const ResetStepIndicator(step: 2),
                const SizedBox(height: 16),
                const Text(
                  'If the address is registered, a code has been sent to '
                  'it. Enter the 6-digit code below. It expires shortly.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(labelText: 'Reset code'),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: AuthValidators.validateOtp,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isLoading ? null : _resend,
                  child: const Text('Resend code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

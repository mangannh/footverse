import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../providers/password_reset_provider.dart';
import '../validators/auth_validators.dart';
import '../widgets/reset_step_indicator.dart';

/// Step 3 of the password-reset flow: set a new password using the reset
/// token captured at step two, then return to login (sprint-13-plan Task 07).
///
/// It reuses the **same** [PasswordResetProvider] instance created by
/// [ForgotPasswordScreen] and passed down through step two; the `resetToken`
/// itself is never read here — the provider holds it in memory and sends it
/// with the request. On success it navigates to [AppRoute.login] with the
/// email as `extra` (so the login screen can pre-fill it and show a success
/// message) — it never signs the caller in, never mutates `AuthProvider`, and
/// never stores anything.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({
    required this.provider,
    required this.email,
    super.key,
  });

  /// The single provider instance created at step one.
  final PasswordResetProvider provider;

  /// The email submitted at step one, carried forward only so the login
  /// screen can pre-fill it once the flow completes.
  final String email;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PasswordResetProvider>.value(
      value: provider,
      child: _ResetPasswordView(email: email),
    );
  }
}

class _ResetPasswordView extends StatefulWidget {
  const _ResetPasswordView({required this.email});

  final String email;

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmation(String? value) {
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final provider = context.read<PasswordResetProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await provider.resetPassword(_newPasswordController.text);
      if (!mounted) {
        return;
      }
      router.goNamed(AppRoute.login, extra: widget.email);
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.watch<PasswordResetProvider>().status ==
        PasswordResetStatus.loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const ResetStepIndicator(step: 3),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    helperText: AuthValidators.passwordRuleHint,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      ),
                    ),
                  ),
                  obscureText: _obscureNewPassword,
                  textInputAction: TextInputAction.next,
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: _validateConfirmation,
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
                      : const Text('Reset password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

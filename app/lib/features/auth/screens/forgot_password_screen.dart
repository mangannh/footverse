import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../models/forgot_password_request.dart';
import '../providers/password_reset_provider.dart';
import '../repositories/auth_repository.dart';
import '../validators/auth_validators.dart';
import '../widgets/reset_step_indicator.dart';

/// Step 1 of the password-reset flow: collect the account email and request
/// the one-time code (sprint-13-plan Task 07).
///
/// It creates the **single** [PasswordResetProvider] instance for the whole
/// flow (Design Note — a fresh provider per screen would drop the
/// `resetToken` between step two and step three) and passes it forward as
/// `state.extra` when it navigates to [AppRoute.verifyResetOtp]. This screen
/// never signs the caller in and never touches `AuthProvider` or any storage.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PasswordResetProvider>(
      create: (_) => PasswordResetProvider(authRepository),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final provider = context.read<PasswordResetProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final email = _emailController.text.trim();
    try {
      await provider.requestOtp(ForgotPasswordRequest(email: email));
      if (!mounted) {
        return;
      }
      router.goNamed(AppRoute.verifyResetOtp, extra: (provider, email));
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
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const ResetStepIndicator(step: 1),
                const SizedBox(height: 16),
                const Text('Enter the email associated with your account.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.email],
                  onFieldSubmitted: (_) => _submit(),
                  validator: AuthValidators.email,
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
                      : const Text('Send code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

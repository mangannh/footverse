import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/validators/auth_validators.dart';
import '../models/change_email_request.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';

/// The re-authenticated email change (security-spec §6 "self only; re-auth";
/// sprint-9-plan item 07).
///
/// It owns a screen-scoped [ProfileProvider] built from the injected
/// [ProfileRepository] (from the composition root, so no widget constructs a
/// `Dio`) and drives its single-flight `changeEmail` write. The form
/// pre-validates the frozen constraints (validation-spec §4, via the reused
/// [AuthValidators]) and the server stays authoritative: a wrong current password
/// is `400 USER_CURRENT_PASSWORD_INVALID` and a taken email is
/// `409 USER_EMAIL_DUPLICATED`, each rendered faithfully as a `SnackBar` on this
/// screen (it never parses the error code). On success it pops back returning
/// `true`; the profile screen then re-fetches, shows the new email, and shows the
/// confirmation `SnackBar` on its own stable `ScaffoldMessenger`. The stale-token
/// consequence is handled transparently by the existing `AuthInterceptor` (no
/// token logic here). It never persists, logs, or echoes a raw password
/// (business-rules → Security).
class ChangeEmailScreen extends StatelessWidget {
  const ChangeEmailScreen({required this.profileRepository, super.key});

  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileProvider>(
      create: (_) => ProfileProvider(profileRepository),
      child: const _ChangeEmailView(),
    );
  }
}

/// The change-email form (new email + current password) with a single-flight
/// submit.
class _ChangeEmailView extends StatefulWidget {
  const _ChangeEmailView();

  @override
  State<_ChangeEmailView> createState() => _ChangeEmailViewState();
}

class _ChangeEmailViewState extends State<_ChangeEmailView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final provider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final request = ChangeEmailRequest(
      newEmail: _newEmailController.text.trim(),
      currentPassword: _currentPasswordController.text,
    );
    try {
      await provider.changeEmail(request);
      router.pop(true);
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating = context.watch<ProfileProvider>().isUpdating;
    return Scaffold(
      appBar: AppBar(title: const Text('Change email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _newEmailController,
                  decoration: const InputDecoration(labelText: 'New email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: AuthValidators.requiredPassword,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isUpdating ? null : _submit,
                  child: isUpdating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

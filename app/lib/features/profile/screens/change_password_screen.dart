import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/validators/auth_validators.dart';
import '../models/change_password_request.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';

/// The re-authenticated password change (security-spec §6 "self only; re-auth";
/// sprint-9-plan item 07).
///
/// It owns a screen-scoped [ProfileProvider] built from the injected
/// [ProfileRepository] (from the composition root, so no widget constructs a
/// `Dio`) and drives its single-flight `changePassword` write. The form
/// pre-validates the frozen constraints (validation-spec §4, via the reused
/// [AuthValidators]) and the server stays authoritative: a wrong current password
/// is the enveloped `400 USER_CURRENT_PASSWORD_INVALID`, rendered faithfully as a
/// `SnackBar` on this screen (it never parses the error code). On success it pops
/// back returning `true`; the confirmation `SnackBar` is shown by the profile
/// screen — the destination whose `ScaffoldMessenger` outlives this route (the
/// Sprint 7 address-form → list precedent). It never persists, logs, or echoes a
/// raw password (business-rules → Security) and adds no token logic.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({required this.profileRepository, super.key});

  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileProvider>(
      create: (_) => ProfileProvider(profileRepository),
      child: const _ChangePasswordView(),
    );
  }
}

/// The change-password form (current + new password) with a single-flight submit.
class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final provider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final request = ChangePasswordRequest(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    try {
      await provider.changePassword(request);
      router.pop(true);
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating = context.watch<ProfileProvider>().isUpdating;
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: AuthValidators.requiredPassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(labelText: 'New password'),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: AuthValidators.password,
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
                      : const Text('Change password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

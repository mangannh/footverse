import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/role.dart';
import '../../auth/models/user_response.dart';
import '../../auth/validators/auth_validators.dart';
import '../models/update_profile_request.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';
import '../validators/profile_validators.dart';

/// The profile a customer reads and edits — the first client consumer of
/// `GET /users/me` (sprint-9-plan item 06). It owns a screen-scoped
/// [ProfileProvider] built from the injected [ProfileRepository] (from the
/// composition root, so no widget constructs a `Dio`) and loads on mount. It
/// shows the read-only identity (email, role, member-since) and an editable
/// section (full name, phone, avatar URL) with a Save action; `email`, `role`,
/// and `enabled` are not editable here (the DTO has no such fields). The
/// change-password and change-email screens are reached by name (sprint-9-plan
/// item 07). Field validation mirrors validation-spec §4 exactly and never
/// contradicts a server `400` (assumption 4/5); the server stays authoritative.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.profileRepository, super.key});

  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileProvider>(
      create: (_) => ProfileProvider(profileRepository)..load(),
      child: const _ProfileView(),
    );
  }
}

/// Renders the profile load states and, when ready, the read-only identity, the
/// editable form, and the credential-screen entries.
///
/// The `AppBar`'s back arrow is Flutter's own automatic one — this screen is
/// reachable only by push (from the account screen), so it already appears
/// with no code here, matching design/03 §17 ("automatic back; never a
/// custom back button").
class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(child: _buildBody(context, provider)),
    );
  }

  Widget _buildBody(BuildContext context, ProfileProvider provider) {
    switch (provider.status) {
      case ProfileStatus.loading:
        return const _ProfileSkeleton();
      case ProfileStatus.error:
        return AppErrorState(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: provider.retry,
        );
      case ProfileStatus.ready:
        final user = provider.user!;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            _ProfileHeader(user: user),
            const SectionHeader(title: 'Account'),
            _InfoRow(label: 'Email', value: user.email),
            _InfoRow(label: 'Role', value: _roleLabel(user.role)),
            _InfoRow(label: 'Member since', value: _formatDate(user.createdAt)),
            const SectionHeader(title: 'Edit profile'),
            _ProfileForm(user: user, isUpdating: provider.isUpdating),
            const SectionHeader(title: 'Security'),
            const _CredentialEntries(),
          ],
        );
    }
  }

  static String _roleLabel(Role role) {
    switch (role) {
      case Role.customer:
        return 'Customer';
      case Role.admin:
        return 'Admin';
    }
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

/// The loading state: an approximation of the header, identity rows, and
/// form fields (design/03 §25, design/04 §1.2) — never a centred spinner.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const <Widget>[
        ListTileSkeleton(),
        SizedBox(height: AppSpacing.lg),
        TextLineSkeleton(widthFactor: 0.5),
        SizedBox(height: AppSpacing.xs),
        TextLineSkeleton(widthFactor: 0.4),
        SizedBox(height: AppSpacing.xs),
        TextLineSkeleton(widthFactor: 0.6),
        SizedBox(height: AppSpacing.lg),
        ListTileSkeleton(),
        ListTileSkeleton(),
        ListTileSkeleton(),
      ],
    );
  }
}

/// The avatar + name header, the first thing this screen shows
/// (design/04 §4.11).
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserResponse user;

  static const double _avatarSize = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          ClipOval(
            child: AppNetworkImage(url: user.avatarUrl, width: _avatarSize),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              user.fullName,
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// One label / value line in the identity section.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  static const double _labelWidth = 112;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _labelWidth,
            child: Text(label, style: textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The editable profile fields (full name, phone, avatar URL) with a Save action.
/// It pre-validates against the frozen constraints (validation-spec §4) — reusing
/// the auth `fullName` / `phone` validators and the profile `avatarUrl` validator
/// (assumption 5) — then drives [ProfileProvider.updateProfile]; the enveloped
/// success or `409 USER_PHONE_DUPLICATED` is rendered as a `SnackBar`. The Save
/// button disables while an update is in flight (single-flight) — already
/// correct, preserved unchanged (design/04 §4.11).
class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.user, required this.isUpdating});

  final UserResponse user;
  final bool isUpdating;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarUrlController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _avatarUrlController = TextEditingController(text: widget.user.avatarUrl);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final provider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final avatarUrl = _avatarUrlController.text.trim();
    final request = UpdateProfileRequest(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
    );
    try {
      await provider.updateProfile(request);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Full name'),
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.name],
            validator: AuthValidators.fullName,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.telephoneNumber],
            validator: AuthValidators.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _avatarUrlController,
            decoration: const InputDecoration(
              labelText: 'Avatar URL (optional)',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            validator: ProfileValidators.avatarUrl,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: widget.isUpdating ? null : _save,
            child: widget.isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// The entries to the two credential screens (sprint-9-plan item 07), reached by
/// their named routes so the system back button returns here.
///
/// A credential screen owns its own screen-scoped [ProfileProvider] and, on a
/// successful write, pops returning `true` — it shows no success `SnackBar`
/// itself, because its `ScaffoldMessenger` is torn down with the popped route.
/// This screen (the stable destination) owns the confirmation instead: a
/// password change confirms directly; an email change first re-fetches
/// `GET /users/me` so the identity section reflects the new email, then
/// confirms — the same pop-a-result-then-refresh flow the address form / list
/// use after a mutation.
class _CredentialEntries extends StatelessWidget {
  const _CredentialEntries();

  Future<void> _openChangePassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await context.pushNamed<bool>(AppRoute.changePassword);
    if (changed ?? false) {
      messenger.showSnackBar(const SnackBar(content: Text('Password changed')));
    }
  }

  Future<void> _openChangeEmail(BuildContext context) async {
    final provider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final changed = await context.pushNamed<bool>(AppRoute.changeEmail);
    if (changed ?? false) {
      await provider.load();
      if (provider.status == ProfileStatus.ready) {
        messenger.showSnackBar(const SnackBar(content: Text('Email changed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openChangePassword(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alternate_email),
          title: const Text('Change email'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openChangeEmail(context),
        ),
      ],
    );
  }
}

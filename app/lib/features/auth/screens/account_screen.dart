import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/repositories/profile_repository.dart';
import '../providers/auth_provider.dart';

/// The signed-in area's minimal shell: it links to the customer's shopping
/// resources and offers logout (sprint-6-plan item 08; sprint-7-plan item 04).
///
/// The Addresses, Wishlist, Orders, and Profile entries push their
/// authenticated routes by name so the system back button returns here. It
/// owns a screen-scoped [ProfileProvider] (Task 14) purely to read the
/// caller's name/email/avatar for the user header — the same read-only
/// `GET /users/me` the profile screen already performs, from a second call
/// site; no provider or repository gained new behaviour. This screen never
/// calls [ProfileProvider.updateProfile]/`changePassword`/`changeEmail`.
/// [AuthProvider.logout] revokes the refresh token and always clears the
/// local session; the resulting auth-state change makes the router redirect
/// this now-unauthenticated route to login on its own (the guard already
/// covers `/account` — the signed-out branch below is defence in depth, not
/// the primary mechanism).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.profileRepository});

  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileProvider>(
      create: (_) => ProfileProvider(profileRepository)..load(),
      child: const _AccountView(),
    );
  }
}

class _AccountView extends StatefulWidget {
  const _AccountView();

  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  bool _loggingOut = false;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign in again next time."),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _signOut(context);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    setState(() => _loggingOut = true);
    await authProvider.logout();
    if (mounted) {
      setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: isAuthenticated ? _buildMenu(context) : const _SignInPrompt(),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        _UserHeader(provider: profileProvider),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Addresses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(AppRoute.addresses),
        ),
        // Task 20, if executed, moves this tile to a bottom-nav tab instead —
        // removing it here is then a one-line change (design/04 §4.12).
        ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: const Text('Wishlist'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(AppRoute.wishlist),
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('My Orders'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(AppRoute.orders),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Profile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(AppRoute.profile),
        ),
        const Divider(),
        // Visually separated from the navigation entries above by the
        // divider, and coloured with the `error` role — never colour alone,
        // the icon and the word "Sign out" both carry it too (design/02
        // §2.4). Requires confirmation; never logs out on a single tap
        // (design/04 §4.12).
        ListTile(
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Sign out',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          trailing: _loggingOut
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _loggingOut ? null : () => _confirmSignOut(context),
        ),
      ],
    );
  }
}

/// The user header: avatar, full name, and email — the first thing this
/// screen shows (design/04 §4.12). [provider]'s `GET /users/me` is a
/// best-effort read for display only: while it loads, a skeleton matches its
/// eventual shape; if it fails, the header still renders (an avatar and a
/// generic label) rather than blocking the whole menu behind a full-screen
/// error, since none of the destinations below depend on this data.
class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.provider});

  final ProfileProvider provider;

  static const double _avatarSize = 56;

  @override
  Widget build(BuildContext context) {
    if (provider.status == ProfileStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: ListTileSkeleton(),
      );
    }
    final theme = Theme.of(context);
    final user = provider.status == ProfileStatus.ready ? provider.user : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          ClipOval(
            child: AppNetworkImage(url: user?.avatarUrl, width: _avatarSize),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user?.fullName ?? 'My account',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed-out state: a sign-in prompt rather than a broken or empty menu
/// (design/04 §4.12). In practice the route guard already redirects a guest
/// away from `/account` before this ever builds; this branch is defence in
/// depth for the moment the session ends while the screen is still on
/// screen, not the primary mechanism.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.person_outline,
      title: 'Sign in to view your account',
      message: 'Sign in to manage your profile, addresses, and orders.',
      actionLabel: 'Sign in',
      onAction: () => context.goNamed(
        AppRoute.login,
        queryParameters: <String, String>{
          'from': GoRouterState.of(context).uri.toString(),
        },
      ),
    );
  }
}

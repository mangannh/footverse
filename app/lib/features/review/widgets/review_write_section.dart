import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../../product/models/review_response.dart';
import '../providers/review_provider.dart';
import 'review_compose_sheet.dart';

/// The **review-owned** write affordance the product detail composes
/// (flutter-guidelines §Feature Boundaries): a "Write a review" control when the
/// caller has no review, and a "You reviewed this — Edit / Delete" control once
/// one is resolved or created (sprint-9-plan item 05). It renders from
/// [ReviewProvider] and takes the product's [reviews] so the provider can resolve
/// the caller's own review by matching [ReviewResponse.userId] (Design
/// Decision 3); it re-implements no eligibility, ownership, or rating rule.
///
/// A guest tap routes to login and back via the existing `from` mechanism
/// (business-rules → Guest capabilities); a signed-in tap opens the compose sheet
/// (create / edit) or a confirmation dialog (delete). Writes are single-flight —
/// the controls disable while one is in flight — and any enveloped `REVIEW_*`
/// rejection is rendered as a transient `SnackBar` (flutter-guidelines §Error
/// Handling). The public review reload after a successful write is the provider's
/// own concern (wired to `ProductDetailProvider.retryReviews` at the composition
/// root), so this widget never touches the product feature's state.
class ReviewWriteSection extends StatelessWidget {
  const ReviewWriteSection({super.key, required this.reviews});

  /// The product's currently loaded reviews, from which the caller's own review
  /// is resolved by userId.
  final List<ReviewResponse> reviews;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReviewProvider>();
    final ownReview = provider.ownReviewFrom(reviews);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ownReview == null
          ? _WriteControl(mutating: provider.isMutating)
          : _OwnerControls(review: ownReview, mutating: provider.isMutating),
    );
  }
}

/// The "Write a review" control shown when the caller has no review. A guest is
/// routed to login; a signed-in caller opens the create sheet.
class _WriteControl extends StatelessWidget {
  const _WriteControl({required this.mutating});

  final bool mutating;

  Future<void> _onTap(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    // Guests browse and read reviews but cannot write them: route to login and
    // return here after sign-in via the existing `from` mechanism (business-rules
    // → Guest capabilities). The client never pre-checks eligibility.
    if (!authProvider.isAuthenticated) {
      final location = GoRouterState.of(context).uri.toString();
      context.goNamed(
        AppRoute.login,
        queryParameters: <String, String>{'from': location},
      );
      return;
    }
    await _composeReview(context);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: mutating ? null : () => _onTap(context),
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Write a review'),
      ),
    );
  }
}

/// The "You reviewed this" control with Edit and Delete, shown once the caller's
/// own review is resolved or created.
class _OwnerControls extends StatelessWidget {
  const _OwnerControls({required this.review, required this.mutating});

  final ReviewResponse review;
  final bool mutating;

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<ReviewProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review'),
        content: const Text(
          'Are you sure you want to delete your review? '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep review'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete review'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await provider.remove(review);
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text('You reviewed this', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: mutating
                  ? null
                  : () => _composeReview(context, existing: review),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: mutating ? null : () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Opens the shared compose sheet and submits the resulting draft — a create when
/// [existing] is null, an edit otherwise. Any enveloped `REVIEW_*` rejection is
/// shown as a `SnackBar`; a dismissed sheet does nothing.
Future<void> _composeReview(
  BuildContext context, {
  ReviewResponse? existing,
}) async {
  final provider = context.read<ReviewProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final draft = await showModalBottomSheet<ReviewDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReviewComposeSheet(
      initialRating: existing?.rating,
      initialComment: existing?.comment,
    ),
  );
  if (draft == null) {
    return;
  }
  try {
    if (existing == null) {
      await provider.submit(draft.rating, draft.comment);
    } else {
      await provider.edit(existing, draft.rating, draft.comment);
    }
  } on AppException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

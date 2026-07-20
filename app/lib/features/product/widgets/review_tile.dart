import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/rating_display.dart';
import '../models/review_response.dart';

/// A single product review (dto-spec §16). Shows the author, rating, comment,
/// date, and an "Edited" indicator — displayed only when `updatedAt` differs
/// from `createdAt`, with no other logic.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final ReviewResponse review;

  static const double _avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final comment = review.comment;
    final isEdited = review.updatedAt != review.createdAt;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Avatar(url: review.userAvatarUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  review.userFullName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // `reviewCount` intentionally omitted: this is one reviewer's
              // own rating, not an aggregate — the null-count extension
              // (design/03 §3, sprint-14-plan Task 07) renders the star and
              // value alone, with no "(N reviews)" suffix that would not
              // apply here.
              RatingDisplay(
                rating: review.rating.toDouble(),
                size: RatingSize.small,
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(comment, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: <Widget>[
              Text(AppDateFormat.format(review.createdAt), style: metaStyle),
              if (isEdited) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text('Edited', style: metaStyle),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The review author's avatar, or a placeholder when they have none.
/// Circular — the one shape exempted from the rectangles-only rule
/// (design/02 §8) — via [ClipOval] over [AppNetworkImage], so the avatar
/// still goes through the shared cache/placeholder/error contract
/// (design/02 §2.5).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: AppNetworkImage(url: url, width: ReviewTile._avatarSize),
    );
  }
}

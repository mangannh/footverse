import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The two size steps for [RatingDisplay] (design/03 §3).
enum RatingSize {
  /// Dense contexts — product cards in a grid.
  small,

  /// Standalone contexts — a review summary header.
  medium,
}

/// Shows an average rating consistently (design/03 §3), replacing the two
/// inline copies in `product_card.dart` and `review_tile.dart`.
///
/// Renders **nothing** when there are no reviews — not `"0.0"`. A zero
/// rating implies *bad*; no rating means *unknown*, and conflating them
/// misinforms the customer.
///
/// ### `reviewCount` unknown (sprint-14-plan Task 07 extension)
///
/// `ProductSummaryResponse` (dto-spec §9) carries `averageRating` but no
/// review count — the list/grid read surface deliberately omits it. Passing
/// `reviewCount` is unchanged from Task 05 and remains fully backward
/// compatible: every existing call site behaves identically. When
/// [reviewCount] is omitted (`null`), this widget falls back to the only
/// other signal it has: because a real review's `rating` is always `1`–`5`
/// (validation-spec), an `averageRating > 0` can **only** occur when at
/// least one review exists — so the rating renders (without a count
/// suffix, since the exact count is genuinely unknown), and `rating <= 0`
/// still renders nothing. This is a deduction from data already on the
/// response, not an invented value (`CLAUDE.md`).
class RatingDisplay extends StatelessWidget {
  const RatingDisplay({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = RatingSize.medium,
  });

  /// The server's `averageRating`, rendered verbatim to one decimal place.
  /// Never computed or rounded beyond display formatting.
  final double rating;

  /// `null` means "unknown" (see class doc); `0` or below always renders
  /// nothing, whether known or unknown.
  final int? reviewCount;

  final RatingSize size;

  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final reviewCount = this.reviewCount;
    final hasReviewCount = reviewCount != null;

    if (hasReviewCount ? reviewCount <= 0 : !(rating > 0)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final valueStyle = size == RatingSize.medium
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodySmall;
    final countStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ratingLabel = rating.toStringAsFixed(1);
    final semanticsLabel = hasReviewCount
        ? 'Rated $ratingLabel out of 5, $reviewCount '
              '${reviewCount == 1 ? 'review' : 'reviews'}.'
        : 'Rated $ratingLabel out of 5.';

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: _iconSize, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xxs),
          Text(ratingLabel, style: valueStyle),
          if (hasReviewCount) ...[
            const SizedBox(width: AppSpacing.xxs),
            Text('($reviewCount)', style: countStyle),
          ],
        ],
      ),
    );
  }
}

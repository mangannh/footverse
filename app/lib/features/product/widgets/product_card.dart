import 'package:flutter/material.dart';

import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/price_text.dart';
import '../../../core/widgets/rating_display.dart';
import '../models/product_summary_response.dart';

/// Presentation variants for [ProductCard] (design/03 §4).
enum ProductCardVariant {
  /// Default — the product grid. The card fills whatever cross-axis width
  /// its parent (a grid cell) gives it.
  grid,

  /// Horizontal carousels (related products). A fixed width, so the card is
  /// measurable inside an unbounded-width scrolling row.
  compact,
}

/// The primary merchandising unit (design/03 §4): a vertical, image-led card
/// rendering only [ProductSummaryResponse] fields. It computes nothing — the
/// server is the single source of truth for price, rating and availability
/// (business-rules).
///
/// Information order is fixed: image → brand → name → price → rating →
/// availability (design/01 §6) — never reordered. The whole card is one tap
/// target, and it emits exactly **one** [Semantics] node summarising brand,
/// name, price, rating and availability, never five separate fragments
/// (design/03 §4 Accessibility).
///
/// There is deliberately **no** wishlist toggle here — it would add a second
/// tap target to a scanning surface and compete with the primary action
/// (design/03 §4 Behaviour). The toggle lives on product detail.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.variant = ProductCardVariant.grid,
  });

  final ProductSummaryResponse product;
  final VoidCallback onTap;
  final ProductCardVariant variant;

  /// Component-tier (design/02 §1): the fixed width of the
  /// [ProductCardVariant.compact] card, used by horizontal carousels so the
  /// card is measurable inside an unbounded-width scrolling row.
  static const double compactWidth = 160;

  /// Component-tier (design/02 §1 — the `ProductCard.imageAspectRatio`
  /// example this section names as legitimate): the vertical space the info
  /// panel (brand, name, price, rating/availability — everything below the
  /// square image) occupies at the base text scale. [ProductGrid] reads
  /// this to compute a `childAspectRatio` that fits the card without
  /// overflow, so the two components never restate this number
  /// independently.
  static const double infoBlockHeight = 168;

  /// The opacity applied to an unavailable product's image (design/03 §4
  /// States). Always paired with the "Out of stock" tag in [_CardInfo] —
  /// never opacity alone (design/02 §2.4).
  static const double _unavailableImageOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // `InkWell` normally contributes its own focus/tap semantics on its own
    // node, separate from its child's — a focusable interactive widget is
    // always its own semantics boundary, so `MergeSemantics` around the
    // content alone cannot fold that node away, and it produces two nodes
    // (an actionable one with no label, and a labelled one with no action).
    // `excludeFromSemantics` + `canRequestFocus: false` remove InkWell's own
    // contribution entirely, and the `Semantics(button:true, onTap:)` below
    // — placed *inside* `MergeSemantics`, alongside the text content — is
    // what the merge actually absorbs the tap action from. The result is
    // one merged node carrying the button flag, the tap action, and the
    // full brand/name/price/rating/availability label together; the ripple
    // and real gesture handling stay on `InkWell.onTap`, unaffected.
    Widget content = Card(
      margin: EdgeInsets.zero,
      elevation: AppElevation.none,
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        canRequestFocus: false,
        child: MergeSemantics(
          child: Semantics(
            button: true,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CardImage(product: product),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _CardInfo(product: product),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (variant == ProductCardVariant.compact) {
      content = SizedBox(width: compactWidth, child: content);
    }
    return content;
  }
}

/// The square, image-led top of the card (design/03 §4, design/02 §2.5).
/// [AppNetworkImage] fills exactly the width its parent gives it — via
/// [LayoutBuilder], never a hardcoded pixel size — so both
/// [ProductCardVariant]s share this one implementation.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.product});

  final ProductSummaryResponse product;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final image = AppNetworkImage(
          url: product.primaryImageUrl,
          width: constraints.maxWidth,
        );
        return product.available
            ? image
            : Opacity(
                opacity: ProductCard._unavailableImageOpacity,
                child: image,
              );
      },
    );
  }
}

/// The info panel below the image, in the fixed order design/01 §6
/// mandates: brand → name → price → rating → availability.
class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.product});

  final ProductSummaryResponse product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.brandName,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          product.name,
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        PriceText(amount: product.basePrice),
        const SizedBox(height: AppSpacing.xxs),
        // Wrap, not Row: RatingDisplay + the availability tag must never
        // overflow the card's width on the narrowest supported phones
        // (design/06 §16) — Wrap reflows to a second line instead.
        Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RatingDisplay(
              rating: product.averageRating,
              size: RatingSize.small,
            ),
            _Availability(available: product.available),
          ],
        ),
      ],
    );
  }
}

/// The availability line (design/03 §4). "In stock" is a plain caption; the
/// unavailable state is the one that must never rely on colour alone, so it
/// is the ratified [AppTag] pairing (design/03 §11 — "Out of stock" uses the
/// `surfaceContainerHighest` role).
class _Availability extends StatelessWidget {
  const _Availability({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!available) {
      return AppTag(
        label: 'Out of stock',
        icon: Icons.error_outline,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
      );
    }
    return Text(
      'In stock',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

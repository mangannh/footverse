import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/product_variant_response.dart';
import '../models/product_variant_status.dart';

/// The product's purchasable sizes (design/03 §8) — replaces
/// `ProductVariantList`'s engineering-vocabulary "Variants" list
/// (sprint-14-plan Task 09).
///
/// Customers buy a **size**, in a **colour** — never a SKU, a stock count, or
/// an Active/Inactive status. Tiles are grouped by colour only when the
/// product genuinely has more than one; unavailable sizes stay visible
/// (dimmed, struck through, unselectable) so a customer can tell "sold out"
/// from "never made". When [onSelect] is provided the grid is single-select
/// (sprint-7-plan item 07) — the chosen variant drives the composed
/// add-to-cart affordance; selection is screen-local UI state passed in by
/// the parent, never held here. Without [onSelect] the grid stays read-only
/// (sprint-6-plan item 11).
class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.variants,
    this.selectedVariantId,
    this.onSelect,
  });

  final List<ProductVariantResponse> variants;

  /// The currently selected variant id (screen-local state owned by the parent).
  final int? selectedVariantId;

  /// Selection callback; when null the grid is read-only.
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (variants.isEmpty) {
      return Text(
        'No sizes available.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final groups = _groupByColor(variants);
    final multiColor = groups.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final entry in groups.entries) ...[
          if (multiColor) ...[
            Text(
              entry.key,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final variant in entry.value)
                _SizeTile(
                  variant: variant,
                  selected: variant.id == selectedVariantId,
                  onSelect: onSelect == null
                      ? null
                      : () => onSelect!(variant.id),
                ),
            ],
          ),
          if (entry.key != groups.keys.last)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  /// Groups [variants] by colour, preserving the order colours first appear
  /// in — a `Map` iterates in insertion order in Dart, so no separate sort
  /// is needed.
  static Map<String, List<ProductVariantResponse>> _groupByColor(
    List<ProductVariantResponse> variants,
  ) {
    final groups = <String, List<ProductVariantResponse>>{};
    for (final variant in variants) {
      groups
          .putIfAbsent(variant.color, () => <ProductVariantResponse>[])
          .add(variant);
    }
    return groups;
  }
}

/// A single size tile (design/03 §8 — the three tile states).
class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.variant,
    required this.selected,
    required this.onSelect,
  });

  final ProductVariantResponse variant;
  final bool selected;

  /// Null when unavailable (out of stock / inactive) or when the grid is
  /// read-only — either way the tile is not tappable.
  final VoidCallback? onSelect;

  bool get _available =>
      variant.status == ProductVariantStatus.active &&
      variant.stockQuantity > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final available = _available;
    final tappable = available && onSelect != null;

    final Color background;
    final Color foreground;
    final Color borderColor;
    if (selected) {
      background = colorScheme.primary;
      foreground = colorScheme.onPrimary;
      borderColor = colorScheme.primary;
    } else if (!available) {
      background = colorScheme.surface;
      foreground = colorScheme.onSurfaceVariant;
      borderColor = colorScheme.outlineVariant;
    } else {
      background = colorScheme.surface;
      foreground = colorScheme.onSurface;
      borderColor = colorScheme.outline;
    }

    return Semantics(
      label:
          'Size ${variant.size}, ${available ? 'available' : 'out of stock'}',
      button: tappable,
      selected: selected,
      enabled: tappable,
      // Out-of-stock tiles are never tappable, but they must stay reachable
      // by keyboard/switch navigation so a screen-reader user learns the
      // size exists rather than silently disappearing (design/03 §8).
      focusable: true,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: tappable ? onSelect : null,
          canRequestFocus: true,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.xxl,
              minHeight: AppSpacing.xxl,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              variant.size,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                decoration: available ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

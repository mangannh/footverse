import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A small, **non-interactive** label for a fact about an item — the
/// read-only counterpart to a chip (design/03 §11).
///
/// [backgroundColor] and [foregroundColor] are always required alongside
/// [label]: `AppTag` cannot be constructed with colour but no word, so state
/// is never conveyed by colour alone. The three ratified uses (discount,
/// out-of-stock, order status) each pass their own documented `colorScheme`
/// pair from the call site — design/03 §11 gives order-status colour as
/// "per status", so this component stays generic rather than hard-coding
/// one specific mapping.
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  /// The word — always shown, never omitted.
  final String label;

  final Color backgroundColor;
  final Color foregroundColor;

  /// An optional companion icon (design/03 §11: the out-of-stock tag pairs
  /// an icon with its word).
  final IconData? icon;

  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = this.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: _iconSize, color: foregroundColor),
              const SizedBox(width: AppSpacing.xxs),
            ],
            // Flexible + ellipsis: a tag is placed in caller-defined,
            // sometimes narrow contexts (e.g. a product card's info panel).
            // `mainAxisSize.min` alone would overflow rather than shrink,
            // since neither the tag's own Row nor its Text otherwise
            // declares a bound.
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

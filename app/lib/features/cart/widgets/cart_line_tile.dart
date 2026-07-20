import 'package:flutter/material.dart';

import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/price_text.dart';
import '../../../core/widgets/quantity_selector.dart';
import '../models/cart_item_response.dart';

/// One cart line (dto-spec §12): a selection control, image, name, colour / size,
/// server-computed `unitPrice` and `lineTotal`, a quantity selector, availability,
/// and a separate remove action. It renders only — every money value is displayed
/// exactly as the server delivered it and the client computes nothing
/// (dto-spec §1).
///
/// [enabled] is false while any mutation is in flight, disabling every mutating
/// affordance so mutations stay single-flight. [onDecrement] is null at quantity 1
/// (the `quantity ≥ 1` lower bound — validation-spec §7), which disables the button
/// so decrementing then does nothing; removing a line is only the [onRemove]
/// action.
///
/// [onSelectionChanged] is null for a line that cannot be checked out (its variant
/// is unavailable), which disables the selection checkbox — so the unavailable
/// state is conveyed by the disabled control together with the icon-and-text
/// [_UnavailableFlag], never by colour alone (design/02 §2.4). Selection is
/// screen-local UI state owned by the parent (sprint-8-plan item 04).
class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.item,
    required this.enabled,
    required this.selected,
    required this.onSelectionChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItemResponse item;
  final bool enabled;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback onRemove;

  static const double _thumbnailSize = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final onSelectionChanged = this.onSelectionChanged;
    return Card(
      elevation: AppElevation.none,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(
                  value: selected,
                  onChanged: onSelectionChanged == null
                      ? null
                      : (value) => onSelectionChanged(value ?? false),
                ),
                const SizedBox(width: AppSpacing.xxs),
                AppNetworkImage(
                  url: item.productImageUrl,
                  width: _thumbnailSize,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.productName,
                        style: textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${item.color} · ${item.size}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      PriceText(amount: item.unitPrice),
                      if (!item.available) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        const _UnavailableFlag(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                QuantitySelector(
                  quantity: item.quantity,
                  onIncrement: onIncrement,
                  onDecrement: onDecrement,
                  enabled: enabled,
                ),
                const Spacer(),
                PriceText(amount: item.lineTotal),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: enabled ? onRemove : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The unavailable marker for a line whose variant is inactive or out of stock.
/// It pairs an icon with text so state is not conveyed by colour alone
/// (design/02 §2.4) — the reference implementation for this pattern
/// (design/03 §13); kept unchanged by the Sprint 14 Cart task.
class _UnavailableFlag extends StatelessWidget {
  const _UnavailableFlag();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.error_outline, size: 16, color: colorScheme.error),
        const SizedBox(width: 4),
        Text(
          'Unavailable',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
        ),
      ],
    );
  }
}

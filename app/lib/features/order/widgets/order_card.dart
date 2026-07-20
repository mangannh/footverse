import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/price_text.dart';
import '../models/order_status.dart';
import '../models/order_summary_response.dart';

/// The canonical style for an [OrderStatus] tag — the word, an icon, and a
/// colour pair from the theme (design/03 §11: "Order status | per status").
///
/// Shared between [OrderCard] (the compact list tag) and the order-detail
/// status banner, which imports this file for the same mapping rather than
/// duplicating it — the two surfaces must always agree on what each status
/// means. Only [OrderStatus.delivered] (success) and [OrderStatus.cancelled]
/// (error) map to a semantic colour role (design/02 §2.4); every other,
/// non-terminal status uses the same neutral treatment already established
/// for `ProductCard`'s "Out of stock" tag — a non-alarming state.
({String label, IconData icon, Color background, Color foreground})
orderStatusTagStyle(OrderStatus status, ColorScheme colorScheme) {
  switch (status) {
    case OrderStatus.pending:
      return (
        label: 'Pending',
        icon: Icons.schedule,
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
    case OrderStatus.confirmed:
      return (
        label: 'Confirmed',
        icon: Icons.check_circle_outline,
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
    case OrderStatus.shipping:
      return (
        label: 'Shipping',
        icon: Icons.local_shipping_outlined,
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
    case OrderStatus.delivered:
      return (
        label: 'Delivered',
        icon: Icons.check_circle,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    case OrderStatus.cancelled:
      return (
        label: 'Cancelled',
        icon: Icons.cancel_outlined,
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
  }
}

/// One order in the caller's history list (design/03 §15, dto-spec §15),
/// extracted from the inline row that used to live in `order_list_screen.dart`.
///
/// Shows only the summary fields the server delivers — `orderCode`, `status`,
/// `total`, `itemCount`, and `createdAt` — each rendered as delivered: the
/// client computes no money and no aggregate (dto-spec §1). The whole card is
/// one tap target. Cancel is deliberately **not** on this card — it is a
/// destructive action that belongs on the detail screen, behind confirmation.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final OrderSummaryResponse order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = orderStatusTagStyle(order.status, theme.colorScheme);
    return Card(
      elevation: AppElevation.none,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppTag(
                    label: tag.label,
                    icon: tag.icon,
                    backgroundColor: tag.background,
                    foregroundColor: tag.foreground,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${order.itemCount} items · '
                '${AppDateFormat.format(order.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              PriceText(amount: order.total, variant: PriceVariant.emphasis),
            ],
          ),
        ),
      ),
    );
  }
}

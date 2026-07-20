import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/price_text.dart';
import '../models/order_item_response.dart';

/// One line of an order (dto-spec §15): a thumbnail, the product name, the
/// colour / size snapshot, the server-computed `unitPrice`, the quantity, and the
/// server-computed `lineTotal`. It renders only — every money value is displayed
/// exactly as the server delivered it and the client computes nothing
/// (dto-spec §1).
///
/// When [onReview] is provided (a delivered order line, sprint-9-plan item 05) it
/// also shows a "Review this product" entry that navigates to the product detail;
/// eligibility stays server-authoritative — this is only the eligibility-clear
/// entry point from a delivered line.
class OrderItemTile extends StatelessWidget {
  const OrderItemTile({super.key, required this.item, this.onReview});

  final OrderItemResponse item;

  /// Invoked to open the product detail for reviewing; null on non-delivered
  /// lines, where no review entry is shown.
  final VoidCallback? onReview;

  static const double _thumbnailSize = 56;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onReview = this.onReview;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppNetworkImage(url: item.productImageUrl, width: _thumbnailSize),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.productName,
                      style: textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${item.color} · ${item.size}',
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: <Widget>[
                        PriceText(
                          amount: item.unitPrice,
                          variant: PriceVariant.compact,
                        ),
                        Text(
                          ' × ${item.quantity}',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              PriceText(amount: item.lineTotal),
            ],
          ),
          if (onReview != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReview,
                style: TextButton.styleFrom(
                  minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
                ),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Review this product'),
              ),
            ),
        ],
      ),
    );
  }
}

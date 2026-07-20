import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/price_text.dart';

/// The server-computed money summary for one order (dto-spec §1, §15):
/// `subtotal`, `discountAmount`, `shippingFee`, `total`, and `couponCode` when
/// present, each rendered exactly as delivered — the client computes none of
/// them. Extracted from order detail's inline `_MoneySummary` / `_MoneyRow`
/// so the same row-of-amounts shape is a single reusable component.
class OrderSummaryTile extends StatelessWidget {
  const OrderSummaryTile({
    super.key,
    required this.subtotal,
    required this.discountAmount,
    required this.shippingFee,
    required this.total,
    this.couponCode,
  });

  final double subtotal;
  final double discountAmount;
  final double shippingFee;
  final double total;
  final String? couponCode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final couponCode = this.couponCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AmountRow(label: 'Subtotal', amount: subtotal),
        _AmountRow(label: 'Discount', amount: discountAmount),
        _AmountRow(label: 'Shipping', amount: shippingFee),
        if (couponCode != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Coupon', style: textTheme.bodyMedium),
                Text(
                  couponCode,
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        const Divider(),
        _AmountRow(
          label: 'Total',
          amount: total,
          variant: PriceVariant.emphasis,
        ),
      ],
    );
  }
}

/// One labelled amount row. [amount] is a server value shown verbatim through
/// [PriceText].
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.variant = PriceVariant.regular,
  });

  final String label;
  final double amount;
  final PriceVariant variant;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = variant == PriceVariant.emphasis
        ? textTheme.titleMedium
        : textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: labelStyle),
          PriceText(amount: amount, variant: variant),
        ],
      ),
    );
  }
}

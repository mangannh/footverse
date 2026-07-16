import 'package:flutter/material.dart';

import '../models/order_status.dart';
import '../models/order_summary_response.dart';
import '../models/payment_status.dart';

/// One order in the caller's history list (dto-spec §15). It shows only the
/// summary fields the server delivers — `orderCode`, `status`, `paymentStatus`,
/// `total`, `itemCount`, and `createdAt` — each rendered as delivered: the client
/// computes no money and no aggregate (the server is the single source of truth).
/// Tapping the row opens the order detail.
class OrderSummaryTile extends StatelessWidget {
  const OrderSummaryTile({super.key, required this.order, required this.onTap});

  final OrderSummaryResponse order;
  final VoidCallback onTap;

  static String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.shipping:
        return 'Shipping';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  static String _paymentLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.paid:
        return 'Paid';
    }
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(order.orderCode, style: textTheme.titleMedium),
            ),
            const SizedBox(width: 8),
            Text('${order.total}', style: textTheme.titleMedium),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(
              '${_statusLabel(order.status)} · '
              '${_paymentLabel(order.paymentStatus)}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              '${order.itemCount} items · ${_formatDate(order.createdAt)}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

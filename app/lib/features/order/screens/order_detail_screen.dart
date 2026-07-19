import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../models/order_detail_response.dart';
import '../models/order_item_response.dart';
import '../models/order_status.dart';
import '../models/payment_method.dart';
import '../models/payment_status.dart';
import '../providers/order_detail_provider.dart';
import '../repositories/order_repository.dart';
import '../widgets/order_item_tile.dart';
import 'payment_webview_screen.dart';

/// The caller's full order with its checkout snapshots and the `PENDING`
/// cancellation (sprint-8-plan item 07). It owns a screen-scoped
/// [OrderDetailProvider] built from the injected [OrderRepository] and loads on
/// mount; the repository arrives from the composition root so no widget constructs
/// a `Dio` (flutter-guidelines §Networking). Every money and snapshot value is
/// rendered exactly as the server delivered it (dto-spec §1); the client never
/// recomputes money and never re-implements the status machine — it displays the
/// server's `status` and offers the cancel affordance only while the order is
/// `PENDING`. It behaves identically whether reached from the order history or the
/// checkout success flow.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderRepository,
  });

  /// The order id resolved from the route path parameter.
  final int orderId;
  final OrderRepository orderRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrderDetailProvider>(
      create: (_) => OrderDetailProvider(orderRepository, orderId)..load(),
      child: _OrderDetailView(orderRepository: orderRepository),
    );
  }
}

/// Renders the order detail and drives the cancel affordance (confirmation dialog
/// then the single-flight provider cancel, with any enveloped rejection shown as a
/// transient `SnackBar`, flutter-guidelines §Error Handling) and, for a
/// `PENDING`/`UNPAID`/`VNPAY` order, the retry-payment affordance (Sprint 13
/// Task 10): it hosts [PaymentWebViewScreen] as a plain pushed route — not the
/// nested checkout route, which owns its own [CheckoutProvider] state this
/// screen has no relation to — and reloads through the existing
/// [OrderDetailProvider.retry] once it returns, so the result is always the
/// server's own answer.
class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView({required this.orderRepository});

  final OrderRepository orderRepository;

  Future<void> _confirmCancel(BuildContext context) async {
    final provider = context.read<OrderDetailProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel order'),
        content: const Text(
          'Are you sure you want to cancel this order? '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await provider.cancel();
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Retries payment for a `PENDING`/`UNPAID`/`VNPAY` order: hosts the gateway
  /// page, then — regardless of outcome — reloads this screen's order through
  /// the existing [OrderDetailProvider.retry] (Design Decision 6; no shortcut).
  Future<void> _retryPayment(BuildContext context, int orderId) async {
    final detailProvider = context.read<OrderDetailProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentWebViewScreen(
          orderId: orderId,
          orderRepository: orderRepository,
        ),
      ),
    );
    if (context.mounted) {
      detailProvider.retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderDetailProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: SafeArea(child: _buildBody(context, provider)),
    );
  }

  Widget _buildBody(BuildContext context, OrderDetailProvider provider) {
    switch (provider.status) {
      case OrderDetailStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case OrderDetailStatus.error:
        return _ErrorView(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: provider.retry,
        );
      case OrderDetailStatus.ready:
        return _buildDetail(context, provider);
    }
  }

  Widget _buildDetail(BuildContext context, OrderDetailProvider provider) {
    final order = provider.order!;
    final canRetryPayment =
        order.status == OrderStatus.pending &&
        order.paymentMethod == PaymentMethod.vnpay &&
        order.paymentStatus == PaymentStatus.unpaid;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _OrderHeader(order: order),
              const SizedBox(height: 16),
              _ShippingSection(order: order),
              const SizedBox(height: 16),
              _ItemsSection(
                items: order.items,
                delivered: order.status == OrderStatus.delivered,
              ),
              const SizedBox(height: 16),
              _MoneySummary(order: order),
              if (order.note != null && order.note!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _NoteSection(note: order.note!),
              ],
            ],
          ),
        ),
        if (canRetryPayment)
          _PayNowBar(onPay: () => _retryPayment(context, order.id)),
        if (order.status == OrderStatus.pending)
          _CancelBar(
            cancelling: provider.isCancelling,
            onCancel: () => _confirmCancel(context),
          ),
      ],
    );
  }
}

/// The order header: code, status, payment, method, and the relevant timestamps
/// (`cancelledAt` / `deliveredAt` only when the server provides them).
class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final OrderDetailResponse order;

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

  static String _paymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.paid:
        return 'Paid';
    }
  }

  static String _paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cod:
        return 'Cash on Delivery';
      case PaymentMethod.vnpay:
        return 'VNPay';
    }
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(order.orderCode, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            _InfoRow(label: 'Status', value: _statusLabel(order.status)),
            _InfoRow(
              label: 'Payment',
              value: _paymentStatusLabel(order.paymentStatus),
            ),
            _InfoRow(
              label: 'Method',
              value: _paymentMethodLabel(order.paymentMethod),
            ),
            _InfoRow(label: 'Placed', value: _formatDate(order.createdAt)),
            if (order.cancelledAt != null)
              _InfoRow(
                label: 'Cancelled',
                value: _formatDate(order.cancelledAt!),
              ),
            if (order.deliveredAt != null)
              _InfoRow(
                label: 'Delivered',
                value: _formatDate(order.deliveredAt!),
              ),
          ],
        ),
      ),
    );
  }
}

/// One label / value line in the header.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 96, child: Text(label, style: textTheme.bodyMedium)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// The shipping snapshot frozen at checkout (dto-spec §15) — recipient, phone, and
/// the full address, rendered exactly as delivered.
class _ShippingSection extends StatelessWidget {
  const _ShippingSection({required this.order});

  final OrderDetailResponse order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Shipping', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(order.shippingRecipientName, style: textTheme.bodyLarge),
            Text(order.shippingRecipientPhone, style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '${order.shippingStreetAddress}, ${order.shippingWard}, '
              '${order.shippingDistrict}, ${order.shippingProvince}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The order's item lines (one [OrderItemTile] per line). On a [delivered] order
/// each line offers a "Review this product" entry that navigates to the product
/// detail by the line's `productId` (sprint-9-plan item 05); eligibility stays
/// server-authoritative.
class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.items, required this.delivered});

  final List<OrderItemResponse> items;
  final bool delivered;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Items (${items.length})', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final item in items)
          OrderItemTile(
            item: item,
            onReview: delivered
                ? () => context.pushNamed(
                    AppRoute.productDetail,
                    pathParameters: <String, String>{'id': '${item.productId}'},
                  )
                : null,
          ),
      ],
    );
  }
}

/// The server-computed money summary (dto-spec §1) — `subtotal`,
/// `discountAmount`, `shippingFee`, `total`, and `couponCode` when present, each
/// rendered exactly as delivered (the client computes none of them).
class _MoneySummary extends StatelessWidget {
  const _MoneySummary({required this.order});

  final OrderDetailResponse order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final couponCode = order.couponCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Summary', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _MoneyRow(label: 'Subtotal', amount: order.subtotal),
            _MoneyRow(label: 'Discount', amount: order.discountAmount),
            _MoneyRow(label: 'Shipping', amount: order.shippingFee),
            if (couponCode != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Coupon', style: textTheme.bodyMedium),
                    Text(couponCode, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            const Divider(),
            _MoneyRow(label: 'Total', amount: order.total, emphasize: true),
          ],
        ),
      ),
    );
  }
}

/// One labelled amount row. [amount] is a server value shown verbatim.
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = emphasize ? textTheme.titleMedium : textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: style),
          Text('$amount', style: style),
        ],
      ),
    );
  }
}

/// The customer note captured at checkout, shown only when present.
class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Note', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(note, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// The retry-payment bar, shown only for a `PENDING`/`UNPAID`/`VNPAY` order
/// (Sprint 13 Task 10, UX Requirements — "the retry affordance on its detail
/// screen"). Tapping opens [PaymentWebViewScreen]; the busy state while the
/// gateway page loads is that screen's own, not this bar's.
class _PayNowBar extends StatelessWidget {
  const _PayNowBar({required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onPay, child: const Text('Pay now')),
        ),
      ),
    );
  }
}

/// The bottom Cancel Order bar, shown only for a `PENDING` order. The button
/// disables and shows a spinner while the cancel is in flight (single-flight).
class _CancelBar extends StatelessWidget {
  const _CancelBar({required this.cancelling, required this.onCancel});

  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cancelling ? null : onCancel,
              child: cancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cancel Order'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full-screen error state with a retry affordance
/// (flutter-guidelines §Error Handling). It renders the enveloped `ORDER_*`
/// message (e.g. `ORDER_FORBIDDEN` / `ORDER_NOT_FOUND`) exactly as delivered.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

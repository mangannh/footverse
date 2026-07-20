import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/format/app_date_format.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../models/order_detail_response.dart';
import '../models/order_item_response.dart';
import '../models/order_status.dart';
import '../models/payment_method.dart';
import '../models/payment_status.dart';
import '../providers/order_detail_provider.dart';
import '../repositories/order_repository.dart';
import '../widgets/order_card.dart';
import '../widgets/order_item_tile.dart';
import '../widgets/order_summary_tile.dart';
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
        return const _OrderDetailSkeleton();
      case OrderDetailStatus.error:
        return AppErrorState(
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
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              // Status is the first thing read — it is why the customer
              // opened the screen (design/04 §4.10).
              _StatusBanner(status: order.status),
              const SizedBox(height: AppSpacing.lg),
              _OrderInfoCard(order: order),
              const SizedBox(height: AppSpacing.lg),
              _ShippingSection(order: order),
              const SizedBox(height: AppSpacing.lg),
              _ItemsSection(
                items: order.items,
                delivered: order.status == OrderStatus.delivered,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SummaryCard(order: order),
              if (order.note != null && order.note!.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _NoteSection(note: order.note!),
              ],
            ],
          ),
        ),
        if (canRetryPayment)
          _PayNowBar(onPay: () => _retryPayment(context, order.id)),
        // Cancel appears only when the server's own status says the order is
        // still PENDING — never shown disabled on a delivered/cancelled
        // order; absence is clearer than a dead control (design/04 §4.10).
        if (order.status == OrderStatus.pending)
          _CancelBar(
            cancelling: provider.isCancelling,
            onCancel: () => _confirmCancel(context),
          ),
      ],
    );
  }
}

/// The status banner: the current status, prominent, as the very first
/// element on the screen — word and icon, using the same colour mapping as
/// [OrderCard]'s tag (design/04 §4.10).
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final OrderStatus status;

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = orderStatusTagStyle(status, theme.colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(style.icon, size: _iconSize, color: style.foreground),
            const SizedBox(width: AppSpacing.sm),
            Text(
              style.label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: style.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading state: an approximation of the banner, info card, item rows,
/// and summary rows (design/03 §25, design/04 §1.2) — never a centred spinner.
class _OrderDetailSkeleton extends StatelessWidget {
  const _OrderDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const <Widget>[
        TextLineSkeleton(widthFactor: 1),
        SizedBox(height: AppSpacing.lg),
        ListTileSkeleton(),
        ListTileSkeleton(),
        SizedBox(height: AppSpacing.lg),
        ListTileSkeleton(),
        SizedBox(height: AppSpacing.lg),
        TextLineSkeleton(widthFactor: 0.6),
        SizedBox(height: AppSpacing.xs),
        TextLineSkeleton(widthFactor: 0.6),
        SizedBox(height: AppSpacing.xs),
        TextLineSkeleton(widthFactor: 0.6),
      ],
    );
  }
}

/// The order's identifying and status-adjacent info: its code, payment status
/// and method, and the relevant timestamps (`cancelledAt` / `deliveredAt`
/// only when the server provides them). The `status` field itself moved to
/// [_StatusBanner]; this card is not repeated here.
class _OrderInfoCard extends StatelessWidget {
  const _OrderInfoCard({required this.order});

  final OrderDetailResponse order;

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: AppElevation.none,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              order.orderCode,
              style: textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              label: 'Payment',
              value: _paymentStatusLabel(order.paymentStatus),
            ),
            _InfoRow(
              label: 'Method',
              value: _paymentMethodLabel(order.paymentMethod),
            ),
            _InfoRow(
              label: 'Placed',
              value: AppDateFormat.format(order.createdAt),
            ),
            if (order.cancelledAt != null)
              _InfoRow(
                label: 'Cancelled',
                value: AppDateFormat.format(order.cancelledAt!),
              ),
            if (order.deliveredAt != null)
              _InfoRow(
                label: 'Delivered',
                value: AppDateFormat.format(order.deliveredAt!),
              ),
          ],
        ),
      ),
    );
  }
}

/// One label / value line in the info card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  static const double _labelWidth = 96;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _labelWidth,
            child: Text(label, style: textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
      elevation: AppElevation.none,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Shipping', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              order.shippingRecipientName,
              style: textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              order.shippingRecipientPhone,
              style: textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${order.shippingStreetAddress}, ${order.shippingWard}, '
              '${order.shippingDistrict}, ${order.shippingProvince}',
              style: textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: AppSpacing.xxs),
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

/// The server-computed money summary card, delegating the row rendering to
/// the shared [OrderSummaryTile] (dto-spec §1 — the client computes none of
/// these amounts).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});

  final OrderDetailResponse order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: AppElevation.none,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Summary', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            OrderSummaryTile(
              subtotal: order.subtotal,
              discountAmount: order.discountAmount,
              shippingFee: order.shippingFee,
              total: order.total,
              couponCode: order.couponCode,
            ),
          ],
        ),
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
      elevation: AppElevation.none,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Note', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              note,
              style: textTheme.bodyMedium,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
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
      elevation: AppElevation.sticky,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
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

  static const double _spinnerSize = 20;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: AppElevation.sticky,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cancelling ? null : onCancel,
              child: cancelling
                  ? const SizedBox(
                      height: _spinnerSize,
                      width: _spinnerSize,
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

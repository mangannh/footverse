import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../address/models/address_response.dart';
import '../../address/repositories/address_repository.dart';
import '../../cart/models/cart_item_response.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/coupon_preview_response.dart';
import '../models/payment_method.dart';
import '../providers/checkout_provider.dart';
import '../repositories/order_repository.dart';

/// The checkout flow (sprint-8-plan item 05): the selected cart lines (read-only),
/// a shipping-address picker, an optional coupon, an optional note, the
/// server-computed summary, and Place Order. It owns a screen-scoped
/// [CheckoutProvider] built from the injected repositories (the composition root
/// supplies them so no widget constructs a `Dio`, flutter-guidelines §Networking)
/// and loads on mount. Every money value shown is server-computed and rendered as
/// delivered; the client computes nothing (dto-spec §1).
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    super.key,
    required this.orderRepository,
    required this.addressRepository,
    required this.cartItemIds,
  });

  final OrderRepository orderRepository;
  final AddressRepository addressRepository;
  final List<int> cartItemIds;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CheckoutProvider>(
      create: (_) =>
          CheckoutProvider(orderRepository, addressRepository, cartItemIds)
            ..load(),
      child: _CheckoutView(cartItemIds: cartItemIds),
    );
  }
}

/// Renders the checkout and drives its affordances. It reads the app-root
/// [CartProvider] only to display the selected lines and to refresh the cart via
/// its public [CartProvider.load] after a successful order — it never touches the
/// cart's internal state (flutter-guidelines §Feature Boundaries).
class _CheckoutView extends StatefulWidget {
  const _CheckoutView({required this.cartItemIds});

  final List<int> cartItemIds;

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  final TextEditingController _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      return;
    }
    final provider = context.read<CheckoutProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.applyCoupon(code);
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _clear() async {
    _couponController.clear();
    final provider = context.read<CheckoutProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.clearCoupon();
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _placeOrder() async {
    final provider = context.read<CheckoutProvider>();
    final cartProvider = context.read<CartProvider>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final order = await provider.placeOrder();
      if (order == null) {
        return;
      }
      // The server removed the purchased lines; refresh the app-root cart through
      // its own public API so the badge and cart screen reflect it.
      cartProvider.load();
      if (order.paymentMethod == PaymentMethod.vnpay) {
        // Host the gateway's page; regardless of what happens there (paid,
        // cancelled, or abandoned) the order detail screen re-reads the
        // order from the server next — no shortcut (Design Decision 6).
        await router.pushNamed(
          AppRoute.paymentWebview,
          pathParameters: <String, String>{'id': '${order.id}'},
          extra: widget.cartItemIds,
        );
        if (!mounted) {
          return;
        }
      }
      router.goNamed(
        AppRoute.orderDetail,
        pathParameters: <String, String>{'id': '${order.id}'},
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _changeAddress() async {
    final provider = context.read<CheckoutProvider>();
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => _AddressPickerSheet(
        addresses: provider.addresses,
        selectedId: provider.selectedAddress?.id,
      ),
    );
    if (selectedId != null) {
      provider.selectAddress(selectedId);
    }
  }

  void _goToAddresses() => context.pushNamed(AppRoute.addresses);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckoutProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(child: _buildBody(provider)),
    );
  }

  Widget _buildBody(CheckoutProvider provider) {
    switch (provider.status) {
      case CheckoutStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CheckoutStatus.error:
        return _ErrorView(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: provider.retry,
        );
      case CheckoutStatus.ready:
        return _buildCheckout(provider);
    }
  }

  Widget _buildCheckout(CheckoutProvider provider) {
    final cart = context.watch<CartProvider>().cart;
    final selectedIds = widget.cartItemIds.toSet();
    final lines = <CartItemResponse>[
      if (cart != null)
        for (final item in cart.items)
          if (selectedIds.contains(item.id)) item,
    ];
    final busy = provider.isPreviewing || provider.isPlacing;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _ItemsSection(lines: lines),
              const SizedBox(height: 24),
              _AddressSection(
                address: provider.selectedAddress,
                onChange: provider.addresses.isEmpty ? null : _changeAddress,
                onAdd: _goToAddresses,
              ),
              const SizedBox(height: 24),
              _PaymentMethodSection(
                selected: provider.paymentMethod,
                enabled: !busy,
                onChanged: provider.selectPaymentMethod,
              ),
              const SizedBox(height: 24),
              _CouponSection(
                controller: _couponController,
                appliedCode: provider.appliedCouponCode,
                busy: busy,
                onApply: _apply,
                onClear: _clear,
              ),
              const SizedBox(height: 24),
              _NoteField(onChanged: provider.setNote),
              const SizedBox(height: 24),
              _SummarySection(
                preview: provider.preview,
                previewing: provider.isPreviewing,
              ),
            ],
          ),
        ),
        _PlaceOrderBar(
          enabled: provider.canPlaceOrder,
          placing: provider.isPlacing,
          onPlace: _placeOrder,
        ),
      ],
    );
  }
}

/// The read-only list of the lines being checked out (server values only — the
/// client sums nothing; the money summary comes from the preview).
class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.lines});

  final List<CartItemResponse> lines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Items (${lines.length})', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${line.productName} · ${line.color} · ${line.size} '
                    '× ${line.quantity}',
                    style: textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${line.lineTotal}', style: textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

/// The shipping-address section: the selected address with a Change affordance,
/// or an Add-address entry when the caller has none (the Sprint 7 address route).
class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.address,
    required this.onChange,
    required this.onAdd,
  });

  final AddressResponse? address;
  final VoidCallback? onChange;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final address = this.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Shipping address', style: textTheme.titleMedium),
            if (address != null)
              TextButton(onPressed: onChange, child: const Text('Change')),
          ],
        ),
        const SizedBox(height: 4),
        if (address == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'You have no saved address yet.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onAdd,
                child: const Text('Add address'),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(address.recipientName, style: textTheme.bodyLarge),
              Text(address.recipientPhone, style: textTheme.bodyMedium),
              Text(
                '${address.streetAddress}, ${address.ward}, '
                '${address.district}, ${address.province}',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
      ],
    );
  }
}

/// The payment-method selector: `COD` (Sprint 8) and `VNPay` (Sprint 13
/// Task 10), defaulting to `COD` (business-rules → Payment). Disabled while a
/// preview or place is in flight, exactly like the coupon affordances.
class _PaymentMethodSection extends StatelessWidget {
  const _PaymentMethodSection({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final PaymentMethod selected;
  final bool enabled;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Payment method', style: textTheme.titleMedium),
        RadioGroup<PaymentMethod>(
          groupValue: selected,
          onChanged: (value) {
            if (enabled && value != null) {
              onChanged(value);
            }
          },
          child: const Column(
            children: <Widget>[
              RadioListTile<PaymentMethod>(
                contentPadding: EdgeInsets.zero,
                title: Text('Cash on Delivery'),
                value: PaymentMethod.cod,
              ),
              RadioListTile<PaymentMethod>(
                contentPadding: EdgeInsets.zero,
                title: Text('VNPay'),
                value: PaymentMethod.vnpay,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The coupon section: a code field with Apply, and — when a coupon is applied —
/// the applied code with Clear. Both affordances are disabled while a preview or
/// place is in flight (single-flight).
class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.controller,
    required this.appliedCode,
    required this.busy,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController controller;
  final String? appliedCode;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final appliedCode = this.appliedCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Coupon', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Coupon code',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: busy ? null : onApply,
              child: const Text('Apply'),
            ),
          ],
        ),
        if (appliedCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Applied: $appliedCode',
                    style: textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The optional customer note (`≤ 500` chars — validation-spec §10; the server
/// stays authoritative).
class _NoteField extends StatelessWidget {
  const _NoteField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      maxLength: 500,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Note (optional)',
        alignLabelWithHint: true,
      ),
    );
  }
}

/// The server-computed checkout summary, rendered exactly as delivered
/// (dto-spec §1 — the client never computes any of these amounts).
class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.preview, required this.previewing});

  final CouponPreviewResponse? preview;
  final bool previewing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = this.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Summary', style: textTheme.titleMedium),
            if (previewing) ...<Widget>[
              const SizedBox(width: 8),
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (preview != null) ...<Widget>[
          _SummaryRow(label: 'Subtotal', amount: preview.subtotal),
          _SummaryRow(label: 'Discount', amount: preview.discountAmount),
          _SummaryRow(label: 'Shipping', amount: preview.shippingFee),
          const Divider(),
          _SummaryRow(label: 'Total', amount: preview.total, emphasize: true),
        ],
      ],
    );
  }
}

/// One labelled amount row. [amount] is a server value shown verbatim.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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

/// The bottom Place Order bar. The button is disabled until an address is
/// selected and no preview / place is in flight; it shows a spinner while placing.
class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({
    required this.enabled,
    required this.placing,
    required this.onPlace,
  });

  final bool enabled;
  final bool placing;
  final VoidCallback onPlace;

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
              onPressed: enabled ? onPlace : null,
              child: placing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Place Order'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The address-picker bottom sheet: the caller's addresses, the selected one
/// marked, tapping one pops its id.
class _AddressPickerSheet extends StatelessWidget {
  const _AddressPickerSheet({
    required this.addresses,
    required this.selectedId,
  });

  final List<AddressResponse> addresses;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          for (final address in addresses)
            ListTile(
              onTap: () => Navigator.of(context).pop(address.id),
              leading: Icon(
                address.id == selectedId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(address.recipientName),
              subtitle: Text(
                '${address.streetAddress}, ${address.ward}, '
                '${address.district}, ${address.province}',
              ),
            ),
        ],
      ),
    );
  }
}

/// The full-screen error state with a retry affordance
/// (flutter-guidelines §Error Handling).
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

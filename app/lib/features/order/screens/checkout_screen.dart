import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/price_text.dart';
import '../../../core/widgets/section_header.dart';
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

  // Screen-local UI feedback for the coupon field (design/03 §16 "Invalid"
  // state) — not provider state: it is a transient rendering concern for
  // this field alone, mirroring the screen-local-state precedent already
  // established elsewhere (e.g. product-detail's variant selection). The
  // provider itself still owns the actual applied coupon / preview.
  String? _couponError;

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
    setState(() => _couponError = null);
    try {
      await provider.applyCoupon(code);
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _couponError = error.message);
      }
    }
  }

  Future<void> _clear() async {
    _couponController.clear();
    final provider = context.read<CheckoutProvider>();
    setState(() => _couponError = null);
    try {
      await provider.clearCoupon();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _couponError = error.message);
      }
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
        return const _CheckoutSkeleton();
      case CheckoutStatus.error:
        return AppErrorState(
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
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              _ItemsSection(lines: lines),
              _AddressSection(
                address: provider.selectedAddress,
                onChange: provider.addresses.isEmpty ? null : _changeAddress,
                onAdd: _goToAddresses,
              ),
              _PaymentMethodSection(
                selected: provider.paymentMethod,
                enabled: !busy,
                onChanged: provider.selectPaymentMethod,
              ),
              _CouponSection(
                controller: _couponController,
                appliedCode: provider.appliedCouponCode,
                discountAmount: provider.preview?.discountAmount,
                errorMessage: _couponError,
                busy: busy,
                onApply: _apply,
                onClear: _clear,
              ),
              _NoteField(onChanged: provider.setNote),
              _SummarySection(preview: provider.preview),
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

/// The loading state: a plausible approximation of the checkout's sections —
/// item lines, the address block, and the summary rows (design/03 §25,
/// design/04 §1.2) — never a centred spinner.
class _CheckoutSkeleton extends StatelessWidget {
  const _CheckoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const <Widget>[
        ListTileSkeleton(),
        ListTileSkeleton(),
        SizedBox(height: AppSpacing.lg),
        TextLineSkeleton(widthFactor: 0.4),
        SizedBox(height: AppSpacing.xs),
        TextLineSkeleton(widthFactor: 0.7),
        SizedBox(height: AppSpacing.xs),
        TextLineSkeleton(widthFactor: 0.9),
        SizedBox(height: AppSpacing.lg),
        TextLineSkeleton(widthFactor: 0.3),
        SizedBox(height: AppSpacing.xs),
        TextLineSkeleton(widthFactor: 0.5),
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
        SectionHeader(title: 'Items (${lines.length})'),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${line.productName} · ${line.color} · ${line.size} '
                    '× ${line.quantity}',
                    style: textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                PriceText(amount: line.lineTotal),
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
        SectionHeader(
          title: 'Shipping address',
          action: address != null ? 'Change' : null,
          onAction: address != null ? onChange : null,
        ),
        if (address == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'You have no saved address yet.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
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
              Text(
                address.recipientName,
                style: textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                address.recipientPhone,
                style: textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${address.streetAddress}, ${address.ward}, '
                '${address.district}, ${address.province}',
                style: textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Payment method'),
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

/// The coupon section (design/03 §16 — entry and applied-result only; coupon
/// *browsing* is out of scope, no such endpoint exists). Renders the four
/// contract states: empty (field + `OutlinedButton` "Apply"), validating
/// (in-button spinner, field disabled), applied (code, discount via
/// [PriceText], and a "Remove" action), and invalid (the server's message
/// beneath the field, with an error icon — never a `SnackBar`, matching a
/// field-level validation error). Both affordances are disabled while a
/// preview or place is in flight (single-flight).
class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.controller,
    required this.appliedCode,
    required this.discountAmount,
    required this.errorMessage,
    required this.busy,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController controller;
  final String? appliedCode;
  final double? discountAmount;
  final String? errorMessage;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onClear;

  static const double _spinnerSize = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appliedCode = this.appliedCode;
    final discountAmount = this.discountAmount;
    final errorMessage = this.errorMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Coupon'),
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
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              onPressed: busy ? null : onApply,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
              ),
              child: busy
                  ? const SizedBox(
                      height: _spinnerSize,
                      width: _spinnerSize,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply'),
            ),
          ],
        ),
        if (appliedCode != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Code: $appliedCode',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (discountAmount != null) PriceText(amount: discountAmount),
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: busy ? null : onClear,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Note'),
        TextField(
          onChanged: onChanged,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

/// The server-computed checkout summary, rendered exactly as delivered
/// (dto-spec §1 — the client never computes any of these amounts). The total
/// is the most prominent number on the screen ([PriceVariant.emphasis]).
class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.preview});

  final CouponPreviewResponse? preview;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Summary'),
        if (preview != null) ...<Widget>[
          _SummaryRow(label: 'Subtotal', amount: preview.subtotal),
          _SummaryRow(label: 'Discount', amount: preview.discountAmount),
          _SummaryRow(label: 'Shipping', amount: preview.shippingFee),
          const Divider(),
          _SummaryRow(
            label: 'Total',
            amount: preview.total,
            variant: PriceVariant.emphasis,
          ),
        ],
      ],
    );
  }
}

/// One labelled amount row. [amount] is a server value shown verbatim through
/// [PriceText].
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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

/// The bottom Place Order bar. The button is disabled until an address is
/// selected and no preview / place is in flight; it shows a spinner while
/// placing — the reference in-button-spinner implementation, kept unchanged
/// by the Sprint 14 Checkout task.
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

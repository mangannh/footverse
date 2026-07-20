import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/price_text.dart';
import '../models/cart_response.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_line_tile.dart';

/// The customer's cart — the first screen whose money the server computes and the
/// client only renders. It reads the application-scoped [CartProvider] (provided
/// at the app root), refreshes on mount, and renders the loading / error / empty
/// / ready states. Mutations run through the provider and any enveloped error
/// (e.g. `PRODUCT_VARIANT_INSUFFICIENT_STOCK`) is shown via a transient
/// `SnackBar` (flutter-guidelines §Error Handling). No widget here calls Dio and
/// no money or aggregate is computed on the client (dto-spec §1).
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Screen-local selection state (the product-detail variant-selection precedent,
  // sprint-7-plan item 07 — never provider state). It holds the ids the caller
  // explicitly *deselected*, so an empty set means every available line is
  // selected by default (sprint-8-plan item 04). Tracking the deselection keeps
  // the default correct on the first frame and as the cart changes, without
  // re-syncing against the async cart.
  final Set<int> _deselectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    // Refresh on mount (the badge may already have loaded the cart on sign-in).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartProvider>().load();
      }
    });
  }

  /// The ids of the currently selected lines: every available line the caller has
  /// not deselected. Unavailable lines can never be selected (business-rules →
  /// Checkout — only an active, in-stock variant can be purchased).
  List<int> _selectedIds(CartResponse cart) => <int>[
    for (final item in cart.items)
      if (item.available && !_deselectedIds.contains(item.id)) item.id,
  ];

  void _toggleSelection(int cartItemId, bool selected) {
    setState(() {
      if (selected) {
        _deselectedIds.remove(cartItemId);
      } else {
        _deselectedIds.add(cartItemId);
      }
    });
  }

  /// Navigates to the checkout route with the selected cart line ids as the typed
  /// `extra` (sprint-8-plan item 04).
  void _goToCheckout(List<int> cartItemIds) {
    context.pushNamed(AppRoute.checkout, extra: cartItemIds);
  }

  /// Runs a provider mutation and renders any [AppException] as a `SnackBar`.
  Future<void> _runMutation(Future<void> Function() action) async {
    try {
      await action();
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.retry,
          child: _buildBody(provider),
        ),
      ),
    );
  }

  Widget _buildBody(CartProvider provider) {
    switch (provider.status) {
      case CartStatus.loading:
        return const _CartSkeleton();
      case CartStatus.error:
        return AppErrorState(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: provider.retry,
        );
      case CartStatus.ready:
        final cart = provider.cart;
        if (cart == null || cart.items.isEmpty) {
          return AppEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Your cart is empty',
            message: 'Add products you love and they will show up here.',
            actionLabel: 'Browse products',
            onAction: () => context.goNamed(AppRoute.catalog),
          );
        }
        return _buildCart(provider, cart);
    }
  }

  Widget _buildCart(CartProvider provider, CartResponse cart) {
    final items = cart.items;
    final selectedIds = _selectedIds(cart);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return CartLineTile(
                item: item,
                enabled: !provider.isMutating,
                selected: item.available && !_deselectedIds.contains(item.id),
                onSelectionChanged: item.available
                    ? (value) => _toggleSelection(item.id, value)
                    : null,
                onIncrement: () => _runMutation(
                  () => provider.updateQuantity(item.id, item.quantity + 1),
                ),
                onDecrement: item.quantity > 1
                    ? () => _runMutation(
                        () =>
                            provider.updateQuantity(item.id, item.quantity - 1),
                      )
                    : null,
                onRemove: () =>
                    _runMutation(() => provider.removeItem(item.id)),
              );
            },
          ),
        ),
        _CartSummary(
          subtotal: cart.subtotal,
          itemCount: cart.itemCount,
          selectedCount: selectedIds.length,
          onCheckout: selectedIds.isEmpty
              ? null
              : () => _goToCheckout(selectedIds),
        ),
      ],
    );
  }
}

/// The loading state: a plausible number of [ListTileSkeleton] rows in place of
/// the eventual cart lines (design/03 §25, design/04 §1.2) — never a centred
/// spinner.
class _CartSkeleton extends StatelessWidget {
  const _CartSkeleton();

  static const int _rowCount = 4;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      itemCount: _rowCount,
      itemBuilder: (context, index) => const ListTileSkeleton(),
    );
  }
}

/// The cart totals bar: the server's whole-cart `subtotal` and `itemCount`,
/// rendered exactly as delivered (dto-spec §12 — the client never recomputes
/// them), the count of selected lines, and the checkout entry
/// (sprint-8-plan item 04). The selected subset's subtotal is **not** computed
/// here — it comes from the checkout preview (sprint-8-plan item 05). [onCheckout]
/// is null when no line is selected, which disables the button.
///
/// This is already the reference sticky-bottom-summary pattern
/// (design/03 §1, design/04 §4.6) — Sprint 14 restyles it with tokens and
/// [PriceText] only; the structure is unchanged.
class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.subtotal,
    required this.itemCount,
    required this.selectedCount,
    required this.onCheckout,
  });

  final double subtotal;
  final int itemCount;
  final int selectedCount;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: AppElevation.sticky,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Subtotal ($itemCount)',
                    style: theme.textTheme.titleMedium,
                  ),
                  PriceText(amount: subtotal, variant: PriceVariant.emphasis),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text('$selectedCount selected', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onCheckout,
                  child: const Text('Checkout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

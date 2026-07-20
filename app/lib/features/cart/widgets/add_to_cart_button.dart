import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cart_provider.dart';

/// The **cart-owned** add-to-cart affordance the product detail composes
/// (flutter-guidelines §Feature Boundaries / §State Ownership): it keeps cart
/// mutation inside the cart feature, so the product feature never touches
/// [CartProvider]. It takes only primitives — the selected [productVariantId] and
/// whether that variant is [purchasable] (the product feature owns the variant
/// data and computes the pre-check) — so it imports no product model.
///
/// It drives [CartProvider.addItem] with quantity 1 (the server merges a repeated
/// variant into the existing line — business-rules → Shopping Cart), disables
/// itself while a cart mutation is in flight (single-flight), routes a signed-out
/// caller to login and back via the existing `from` mechanism, and renders any
/// enveloped rejection (`PRODUCT_VARIANT_INACTIVE` /
/// `PRODUCT_VARIANT_INSUFFICIENT_STOCK`) faithfully via a `SnackBar`. The client
/// pre-check ([purchasable]) mirrors the frozen rule for UX; the server stays
/// authoritative.
///
/// This is the screen's one primary CTA (design/03 §1), so it renders through
/// [AppPrimaryButton] — full width, in-button spinner while mutating, width
/// unchanged between states. The label is derived, not fixed, matching the
/// three states design/04 §4.4 specifies: "Select a size" when nothing is
/// chosen yet, "Out of stock" when the chosen variant isn't purchasable, and
/// "Add to cart" otherwise (sprint-14-plan Task 09).
class AddToCartButton extends StatelessWidget {
  const AddToCartButton({
    super.key,
    required this.productVariantId,
    required this.purchasable,
    this.onAdded,
  });

  /// The selected variant, or null when no variant is selected yet.
  final int? productVariantId;

  /// The client-side pre-check: true only when the selected variant is active
  /// and in stock. False when nothing is selected.
  final bool purchasable;

  /// Called after a successful add, **instead of** the default "Added to
  /// cart" snackbar — so a caller that wants a richer confirmation (e.g. a
  /// "View cart" action) can supply its own. `null` (the default) keeps the
  /// existing bare-snackbar behaviour unchanged, so every call site that
  /// does not pass it keeps working exactly as before.
  final VoidCallback? onAdded;

  String get _label {
    if (productVariantId == null) {
      return 'Select a size';
    }
    if (!purchasable) {
      return 'Out of stock';
    }
    return 'Add to cart';
  }

  @override
  Widget build(BuildContext context) {
    final mutating = context.select<CartProvider, bool>((p) => p.isMutating);
    final variantId = productVariantId;
    final enabled = purchasable && variantId != null && !mutating;
    return AppPrimaryButton(
      label: _label,
      loading: mutating,
      onPressed: enabled ? () => _addToCart(context, variantId) : null,
    );
  }

  Future<void> _addToCart(BuildContext context, int variantId) async {
    // Guests cannot use the cart: route to login and return to this page after
    // sign-in via the existing `from` mechanism (business-rules → Guest
    // capabilities); the server stays authoritative on the cart itself.
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      final location = GoRouterState.of(context).uri.toString();
      context.goNamed(
        AppRoute.login,
        queryParameters: <String, String>{'from': location},
      );
      return;
    }

    final cartProvider = context.read<CartProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final onAdded = this.onAdded;
    try {
      await cartProvider.addItem(variantId);
      if (onAdded != null) {
        onAdded();
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Added to cart')));
      }
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

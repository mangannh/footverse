import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../../address/models/address_response.dart';
import '../../address/repositories/address_repository.dart';
import '../models/coupon_preview_request.dart';
import '../models/coupon_preview_response.dart';
import '../models/order_detail_response.dart';
import '../models/payment_method.dart';
import '../models/place_order_request.dart';
import '../repositories/order_repository.dart';

/// Lifecycle of the checkout's initial load (address book + first preview), which
/// drives the full-screen states.
enum CheckoutStatus { loading, ready, error }

/// Owns the checkout flow state (flutter-guidelines §State Management).
///
/// It is **screen-scoped** — created by the checkout screen, like the Sprint 7
/// address provider — because no other surface reads checkout state. On [load] it
/// reads the caller's addresses (via [AddressRepository] — the sanctioned
/// order → address dependency, mirroring the backend `OrderService → AddressService`
/// arrow, sprint-4-plan item 06), selects the default address, and previews the
/// selected `cartItemIds` with no coupon (`POST /coupons/validate`) to obtain the
/// **server-computed** `subtotal` / `discountAmount` / `shippingFee` / `total`
/// (dto-spec §1 — the client never computes money). Applying or clearing a coupon
/// re-previews; a rejected coupon (`COUPON_*`) is rethrown for the screen to
/// surface and leaves the last valid preview and applied code untouched.
/// [placeOrder] submits `POST /orders` and returns the created order. The preview
/// and the place call are each **single-flight** (the Sprint 7 mutation-guard
/// idiom — the corresponding affordances are disabled while one is in flight), so
/// two responses can never apply out of order.
class CheckoutProvider extends ChangeNotifier {
  CheckoutProvider(
    this._orderRepository,
    this._addressRepository,
    this._cartItemIds,
  );

  final OrderRepository _orderRepository;
  final AddressRepository _addressRepository;
  final List<int> _cartItemIds;

  CheckoutStatus _status = CheckoutStatus.loading;
  AppException? _error;

  List<AddressResponse> _addresses = <AddressResponse>[];
  int? _selectedAddressId;

  CouponPreviewResponse? _preview;
  String? _appliedCouponCode;
  String _note = '';
  PaymentMethod _paymentMethod = PaymentMethod.cod;

  bool _previewing = false;
  bool _placing = false;
  bool _disposed = false;

  /// The initial-load lifecycle status.
  CheckoutStatus get status => _status;

  /// The load error, set only while [status] is [CheckoutStatus.error].
  AppException? get error => _error;

  /// The caller's addresses, in the server's order.
  List<AddressResponse> get addresses => List.unmodifiable(_addresses);

  /// The selected shipping address, or null when the caller has none.
  AddressResponse? get selectedAddress => _addressById(_selectedAddressId);

  /// The server-computed checkout summary; null only before the first preview.
  CouponPreviewResponse? get preview => _preview;

  /// The applied coupon code, or null when none is applied.
  String? get appliedCouponCode => _appliedCouponCode;

  /// The selected payment method (Sprint 13 Task 10), defaulting to
  /// [PaymentMethod.cod].
  PaymentMethod get paymentMethod => _paymentMethod;

  /// True while a preview (`POST /coupons/validate`) is in flight.
  bool get isPreviewing => _previewing;

  /// True while a place-order (`POST /orders`) is in flight.
  bool get isPlacing => _placing;

  /// The order can be placed: the initial load is ready, an address is selected,
  /// and neither a preview nor a place is in flight.
  bool get canPlaceOrder =>
      _status == CheckoutStatus.ready &&
      _selectedAddressId != null &&
      !_previewing &&
      !_placing;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Loads the address book and the initial (coupon-free) preview on screen mount.
  Future<void> load() async {
    _status = CheckoutStatus.loading;
    _error = null;
    _safeNotify();
    try {
      _addresses = await _addressRepository.getAddresses();
      _selectedAddressId = _defaultAddressId(_addresses);
      _preview = await _fetchPreview(null);
      _appliedCouponCode = null;
      _status = CheckoutStatus.ready;
    } on AppException catch (exception) {
      _error = exception;
      _status = CheckoutStatus.error;
    }
    _safeNotify();
  }

  /// Retries the initial load after a [CheckoutStatus.error].
  Future<void> retry() => load();

  /// Selects a shipping address (the "Change address" affordance).
  void selectAddress(int addressId) {
    _selectedAddressId = addressId;
    _safeNotify();
  }

  /// Stores the customer note (submitted with the order). It drives no derived UI
  /// and so does not notify; the field enforces the `≤ 500` length
  /// (validation-spec §10) and the server stays authoritative.
  void setNote(String value) {
    _note = value;
  }

  /// Selects the payment method (the checkout screen's COD / VNPay selector,
  /// Sprint 13 Task 10).
  void selectPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    _safeNotify();
  }

  /// Applies a coupon by re-pricing the selected items with [code].
  ///
  /// On a `COUPON_*` rejection the [AppException] is rethrown (never swallowed) so
  /// the screen can surface it; the last valid preview and applied code are left
  /// untouched (business-rules → Checkout; the summary never resets on a bad
  /// coupon and the order is not blocked).
  Future<void> applyCoupon(String code) => _reprice(code);

  /// Clears the applied coupon by re-pricing the selected items with no code.
  Future<void> clearCoupon() => _reprice(null);

  Future<void> _reprice(String? code) async {
    if (_previewing || _placing) {
      return;
    }
    _previewing = true;
    _safeNotify();
    try {
      final preview = await _fetchPreview(code);
      _preview = preview;
      _appliedCouponCode = code;
    } finally {
      _previewing = false;
      _safeNotify();
    }
  }

  /// Places the order from the selected items, address, coupon, note, and
  /// payment method.
  ///
  /// Returns the created [OrderDetailResponse] on success, or null when the call
  /// is not currently allowed (no address, or a preview / place already in
  /// flight — single-flight). Rethrows the [AppException] on a server rejection
  /// (`PRODUCT_VARIANT_*`, `CART_ITEM_*`, `ADDRESS_*`, `COUPON_*`) so the screen
  /// renders it; no order is placed and the state is unchanged.
  ///
  /// [PlaceOrderRequest.paymentMethod] is left unset for [PaymentMethod.cod]
  /// (Sprint 13 Task 10, sprint-13-plan Design Notes — the server already
  /// defaults an absent value to `COD`) so a `COD` checkout serializes a
  /// request byte-for-byte identical to before this sprint; only an explicit
  /// `VNPAY` choice is ever sent.
  Future<OrderDetailResponse?> placeOrder() async {
    final addressId = _selectedAddressId;
    if (_placing || _previewing || addressId == null) {
      return null;
    }
    _placing = true;
    _safeNotify();
    try {
      final note = _note.trim();
      return await _orderRepository.placeOrder(
        PlaceOrderRequest(
          cartItemIds: _cartItemIds,
          addressId: addressId,
          couponCode: _appliedCouponCode,
          note: note.isEmpty ? null : note,
          paymentMethod: _paymentMethod == PaymentMethod.cod
              ? null
              : _paymentMethod,
        ),
      );
    } finally {
      _placing = false;
      _safeNotify();
    }
  }

  Future<CouponPreviewResponse> _fetchPreview(String? code) {
    return _orderRepository.previewCoupon(
      CouponPreviewRequest(cartItemIds: _cartItemIds, code: code),
    );
  }

  int? _defaultAddressId(List<AddressResponse> addresses) {
    for (final address in addresses) {
      if (address.isDefault) {
        return address.id;
      }
    }
    return addresses.isEmpty ? null : addresses.first.id;
  }

  AddressResponse? _addressById(int? id) {
    if (id == null) {
      return null;
    }
    for (final address in _addresses) {
      if (address.id == id) {
        return address;
      }
    }
    return null;
  }

  // Guards against notifying after disposal: an in-flight preview or place that
  // completes once the screen (and this provider) is gone must not notify.
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

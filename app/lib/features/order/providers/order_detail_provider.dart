import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../models/order_detail_response.dart';
import '../repositories/order_repository.dart';

/// Lifecycle of the order-detail load, which drives the full-screen states.
enum OrderDetailStatus { loading, ready, error }

/// Owns one order's detail state (flutter-guidelines §State Management).
///
/// It is **screen-scoped** — created by the order-detail screen, like the Sprint 6
/// product-detail provider — because no other surface reads it; it needs no
/// sign-out reset (it lives and dies with a guarded route). On [load] it fetches
/// the order (`GET /orders/{id}`); a failure moves to [OrderDetailStatus.error]
/// with a retry affordance and preserves the enveloped [AppException] (incl.
/// `ORDER_FORBIDDEN` / `ORDER_NOT_FOUND` — error-spec §8.11). [cancel]
/// (`POST /orders/{id}/cancel`) replaces the whole state with the returned
/// [OrderDetailResponse] on success and is **single-flight** (the Sprint 7
/// mutation-guard idiom — the affordance disables while the call is in flight); a
/// rejection (`ORDER_NOT_CANCELLABLE`, …) is rethrown for the screen to surface
/// and leaves the order unchanged. It performs no client-side status arithmetic:
/// it exposes the server's `status` and the screen decides only whether to *show*
/// the cancel affordance (business-rules → Cancellation).
class OrderDetailProvider extends ChangeNotifier {
  OrderDetailProvider(this._orderRepository, this._orderId);

  final OrderRepository _orderRepository;
  final int _orderId;

  OrderDetailStatus _status = OrderDetailStatus.loading;
  OrderDetailResponse? _order;
  AppException? _error;
  bool _cancelling = false;
  bool _disposed = false;

  // Incremented on every load so an in-flight load whose captured id no longer
  // matches is a stale request whose response is discarded — two overlapping
  // loads/retries can never apply out of order (mirrors OrderListProvider).
  int _requestId = 0;

  /// The load lifecycle status.
  OrderDetailStatus get status => _status;

  /// The loaded order; null before the first successful load.
  OrderDetailResponse? get order => _order;

  /// The load error, set only while [status] is [OrderDetailStatus.error].
  AppException? get error => _error;

  /// True while a cancel (`POST /orders/{id}/cancel`) is in flight.
  bool get isCancelling => _cancelling;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Loads the order (called once on screen mount).
  Future<void> load() async {
    final requestId = ++_requestId;
    _status = OrderDetailStatus.loading;
    _error = null;
    _safeNotify();
    try {
      final order = await _orderRepository.getMyOrder(_orderId);
      if (requestId != _requestId) {
        return;
      }
      _order = order;
      _status = OrderDetailStatus.ready;
    } on AppException catch (exception) {
      if (requestId != _requestId) {
        return;
      }
      _error = exception;
      _status = OrderDetailStatus.error;
    }
    _safeNotify();
  }

  /// Retries the load after an [OrderDetailStatus.error].
  Future<void> retry() => load();

  /// Cancels the order, replacing the whole state with the server's returned
  /// order on success.
  ///
  /// No-op when a cancel is already in flight (single-flight). Rethrows the
  /// [AppException] on a server rejection (`ORDER_NOT_CANCELLABLE`,
  /// `ORDER_FORBIDDEN`, `ORDER_NOT_FOUND`) so the screen renders the enveloped
  /// message; the order is left unchanged (the client restores no stock and
  /// touches no coupon — it displays the server's result).
  Future<void> cancel() async {
    if (_cancelling) {
      return;
    }
    _cancelling = true;
    _safeNotify();
    try {
      _order = await _orderRepository.cancelOrder(_orderId);
    } finally {
      _cancelling = false;
      _safeNotify();
    }
  }

  // Guards against notifying after disposal: an in-flight load or cancel that
  // completes once the screen (and this provider) is gone must not notify.
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../models/order_detail_response.dart';
import '../models/payment_url_response.dart';
import '../repositories/order_repository.dart';

/// Lifecycle of the currently in-flight payment step.
enum PaymentFlowStatus { idle, loading, success, error }

/// Owns the VNPay sandbox payment flow for one order (sprint-13-plan Task 10):
/// requesting the signed payment URL, then — once the WebView reports the
/// gateway sent the browser back to the configured return URL — reloading the
/// order from the server.
///
/// It is **screen-scoped**: created by [PaymentWebViewScreen] (never at the app
/// root) and disposed with it, so it never outlives the payment flow it serves
/// (Design Note — the flow is a short-lived, self-contained interaction, exactly
/// like the Sprint 7 `AddressProvider` / Sprint 13 `PasswordResetProvider`
/// precedent).
///
/// Both [requestPaymentUrl] and [reloadOrder] are **single-flight** (a call
/// while [status] is already [PaymentFlowStatus.loading] is ignored) and
/// **rethrow** the repository's [AppException] unchanged so the screen renders
/// the enveloped message (flutter-guidelines §Error Handling). This provider
/// reads **no** gateway query parameter, computes **no** signature, and decides
/// **no** payment outcome itself — [reloadOrder] simply replays
/// `GET /orders/{id}` and exposes exactly the [OrderDetailResponse] the server
/// returns; the caller's `paymentStatus` is the single source of truth
/// (business-rules → Payment, Design Decision 6).
class PaymentProvider extends ChangeNotifier {
  PaymentProvider(this._repository, this._orderId);

  final OrderRepository _repository;
  final int _orderId;

  PaymentFlowStatus _status = PaymentFlowStatus.idle;
  AppException? _error;
  PaymentUrlResponse? _paymentUrl;
  OrderDetailResponse? _order;
  bool _disposed = false;

  /// The current step's lifecycle status.
  PaymentFlowStatus get status => _status;

  /// The current step's error, set only while [status] is
  /// [PaymentFlowStatus.error].
  AppException? get error => _error;

  /// The signed payment URL, set once [requestPaymentUrl] succeeds.
  PaymentUrlResponse? get paymentUrl => _paymentUrl;

  /// The order as last reloaded from the server by [reloadOrder]; null until
  /// the WebView has reported a return.
  OrderDetailResponse? get order => _order;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Requests the signed VNPay sandbox payment URL (`POST /orders/{id}/payment`)
  /// for the WebView to open.
  Future<void> requestPaymentUrl() => _run(() async {
    _paymentUrl = await _repository.createPaymentUrl(_orderId);
  });

  /// Reloads the order (`GET /orders/{id}`) after the WebView reports the
  /// gateway sent the browser back to the configured return URL — the **only**
  /// signal this provider ever acts on; the reloaded [order] is the server's
  /// answer, never inferred from anything the WebView saw.
  Future<void> reloadOrder() => _run(() async {
    _order = await _repository.getMyOrder(_orderId);
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_status == PaymentFlowStatus.loading) {
      return;
    }
    _status = PaymentFlowStatus.loading;
    _error = null;
    _safeNotify();
    try {
      await action();
      _status = PaymentFlowStatus.success;
    } on AppException catch (exception) {
      _error = exception;
      _status = PaymentFlowStatus.error;
      _safeNotify();
      rethrow;
    }
    _safeNotify();
  }

  // Guards against notifying after disposal: a step that completes once the
  // screen (and this provider) is gone must not call notifyListeners.
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

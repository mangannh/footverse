import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/models/page_response.dart';
import '../models/order_summary_response.dart';
import '../repositories/order_repository.dart';

/// Lifecycle of the first-page load, which drives the full-screen states.
enum OrderListStatus { loading, ready, error }

/// Owns the order-history state: the accumulated orders (in the server's
/// `createdAt` descending order — the client applies none of its own,
/// business-rules → Order), the paging cursor, and the loading / error / empty
/// states with a retry affordance on the load error
/// (flutter-guidelines §State Management / §Error Handling).
///
/// It is **screen-scoped** — created by the history screen, like the Sprint 6
/// catalog list provider — because no other surface reads order-history state; it
/// needs no sign-out reset (it lives and dies with a guarded route). It
/// coordinates state and calls the repository only; it holds no UI and never
/// computes money or aggregates (the server is the single source of truth).
/// Pagination reuses the Sprint 6 infinite-scroll idiom verbatim: [loadNextPage]
/// appends the next page, is single-flight, stops once the last page is reached,
/// and discards a stale response via the request-generation guard.
class OrderListProvider extends ChangeNotifier {
  OrderListProvider(this._orderRepository);

  static const int _pageSize = 20;

  final OrderRepository _orderRepository;

  OrderListStatus _status = OrderListStatus.loading;
  List<OrderSummaryResponse> _orders = <OrderSummaryResponse>[];
  int _page = 0;
  bool _last = false;
  bool _loadingNextPage = false;
  AppException? _error;
  AppException? _nextPageError;

  // Incremented on every reload so an in-flight next-page load whose captured id
  // no longer matches is a stale request whose response is discarded (a retry
  // that supersedes it).
  int _requestId = 0;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Guards against notifying after disposal: an in-flight load that completes
  // once the screen (and this provider) is gone must not call notifyListeners.
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  OrderListStatus get status => _status;
  List<OrderSummaryResponse> get orders => List.unmodifiable(_orders);
  bool get loadingNextPage => _loadingNextPage;

  /// The first-page error, set only while [status] is [OrderListStatus.error].
  AppException? get error => _error;

  /// The last next-page error, set when appending a page failed; the existing
  /// orders are preserved.
  AppException? get nextPageError => _nextPageError;

  /// True when the first page loaded successfully but returned no orders.
  bool get isEmpty => _status == OrderListStatus.ready && _orders.isEmpty;

  /// Loads the first page (called once on screen mount).
  Future<void> load() => _reload();

  /// Retries the first-page load after a [OrderListStatus.error].
  Future<void> retry() => _reload();

  /// Appends the next page when scrolling nears the bottom. No-op unless the
  /// first page is shown, and never while a load is in flight or once the last
  /// page has been reached — so no duplicate or surplus request is issued.
  Future<void> loadNextPage() async {
    if (_status != OrderListStatus.ready) {
      return;
    }
    if (_loadingNextPage || _last) {
      return;
    }
    final requestId = _requestId;
    _loadingNextPage = true;
    _nextPageError = null;
    _safeNotify();
    final next = _page + 1;
    try {
      final page = await _fetch(next);
      if (requestId != _requestId) {
        return;
      }
      _orders = <OrderSummaryResponse>[..._orders, ...page.content];
      _page = next;
      _last = page.last;
    } on AppException catch (exception) {
      if (requestId != _requestId) {
        return;
      }
      _nextPageError = exception;
    } finally {
      // Only the current request owns the loading flag; a superseded one leaves
      // the reload's state untouched.
      if (requestId == _requestId) {
        _loadingNextPage = false;
        _safeNotify();
      }
    }
  }

  /// Clears the list, resets to the first page, and reloads — the single path
  /// both the initial load and a retry funnel through.
  Future<void> _reload() async {
    final requestId = ++_requestId;
    _status = OrderListStatus.loading;
    _orders = <OrderSummaryResponse>[];
    _page = 0;
    _last = false;
    _loadingNextPage = false;
    _error = null;
    _nextPageError = null;
    _safeNotify();
    try {
      final page = await _fetch(0);
      if (requestId != _requestId) {
        return;
      }
      _orders = page.content;
      _last = page.last;
      _status = OrderListStatus.ready;
    } on AppException catch (exception) {
      if (requestId != _requestId) {
        return;
      }
      _error = exception;
      _status = OrderListStatus.error;
    }
    _safeNotify();
  }

  Future<PageResponse<OrderSummaryResponse>> _fetch(int page) {
    return _orderRepository.getMyOrders(page: page, size: _pageSize);
  }
}

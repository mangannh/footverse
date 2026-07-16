import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/models/api_response.dart';
import '../../../shared/models/page_response.dart';
import '../models/coupon_preview_request.dart';
import '../models/coupon_preview_response.dart';
import '../models/order_detail_response.dart';
import '../models/order_summary_response.dart';
import '../models/place_order_request.dart';

/// The typed client of the five frozen customer order/checkout endpoints
/// (dto-spec §20). The coupon-preview call lives here because the coupon concern
/// is owned by the order module (architecture-spec §4) — there is no separate
/// `CouponRepository`.
///
/// It only calls the API, unwraps the [ApiResponse] envelope, and returns the
/// typed payload — throwing [AppException] on failure (the injected [Dio]'s
/// `ErrorInterceptor` has already mapped the transport error, and its
/// `AuthInterceptor` has attached the CUSTOMER bearer). It holds no business
/// logic and touches no storage or navigation, so every enveloped business error
/// (the `COUPON_*`, `PRODUCT_VARIANT_*`, `CART_ITEM_*`, `ADDRESS_*`, and `ORDER_*`
/// codes of error-spec §8.6/§8.8/§8.9/§8.10/§8.11) propagates unchanged as an
/// [AppException] carrying the registry code.
class OrderRepository {
  const OrderRepository(this._dio);

  static const String _couponValidatePath = '/api/v1/coupons/validate';
  static const String _ordersPath = '/api/v1/orders';

  final Dio _dio;

  /// `POST /coupons/validate` — the server-computed checkout summary for the
  /// selected cart items, optionally applying a coupon.
  Future<CouponPreviewResponse> previewCoupon(
    CouponPreviewRequest request,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _couponValidatePath,
        data: request.toJson(),
      );
      final envelope = ApiResponse<CouponPreviewResponse>.fromJson(
        response.data!,
        (json) => CouponPreviewResponse.fromJson(json! as Map<String, dynamic>),
      );
      return envelope.data!;
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `POST /orders` — place an order from the caller's selected cart items.
  Future<OrderDetailResponse> placeOrder(PlaceOrderRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _ordersPath,
        data: request.toJson(),
      );
      return _unwrapOrder(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `GET /orders` — the caller's orders, paginated and most-recent-first as the
  /// server returns them.
  Future<PageResponse<OrderSummaryResponse>> getMyOrders({
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, dynamic>{'page': page, 'size': size};
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _ordersPath,
        queryParameters: query,
      );
      final envelope = ApiResponse<PageResponse<OrderSummaryResponse>>.fromJson(
        response.data!,
        (json) => PageResponse<OrderSummaryResponse>.fromJson(
          json! as Map<String, dynamic>,
          (item) =>
              OrderSummaryResponse.fromJson(item! as Map<String, dynamic>),
        ),
      );
      return envelope.data!;
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `GET /orders/{id}` — one of the caller's orders in full detail.
  Future<OrderDetailResponse> getMyOrder(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_ordersPath/$id');
      return _unwrapOrder(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `POST /orders/{id}/cancel` — cancel one of the caller's `PENDING` orders,
  /// returning the cancelled order.
  Future<OrderDetailResponse> cancelOrder(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_ordersPath/$id/cancel',
      );
      return _unwrapOrder(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  OrderDetailResponse _unwrapOrder(Response<Map<String, dynamic>> response) {
    final envelope = ApiResponse<OrderDetailResponse>.fromJson(
      response.data!,
      (json) => OrderDetailResponse.fromJson(json! as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  AppException _asAppException(DioException exception) {
    final error = exception.error;
    if (error is AppException) {
      return error;
    }
    return const AppException(message: 'An unexpected error occurred');
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/order/models/coupon_preview_request.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/models/place_order_request.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'order_repository_test.mocks.dart';

Map<String, dynamic> _previewData() => <String, dynamic>{
  'code': 'SUMMER10',
  'name': 'Summer Sale',
  'subtotal': 3300000.00,
  'discountAmount': 330000.00,
  'shippingFee': 30000.00,
  'total': 3000000.00,
};

Map<String, dynamic> _orderItemData() => <String, dynamic>{
  'id': 900,
  'productVariantId': 100,
  'productId': 55,
  'productName': 'Air Zoom Pegasus',
  'productImageUrl': 'https://cdn.example.com/p1.jpg',
  'color': 'Black',
  'size': '42',
  'unitPrice': 1650000.00,
  'quantity': 2,
  'lineTotal': 3300000.00,
};

Map<String, dynamic> _orderDetailData() => <String, dynamic>{
  'id': 700,
  'orderCode': 'FV-20250115103000123',
  'status': 'PENDING',
  'paymentMethod': 'COD',
  'paymentStatus': 'UNPAID',
  'subtotal': 3300000.00,
  'discountAmount': 330000.00,
  'shippingFee': 30000.00,
  'total': 3000000.00,
  'couponCode': 'SUMMER10',
  'shippingRecipientName': 'Nguyen Van A',
  'shippingRecipientPhone': '0901234567',
  'shippingProvince': 'Hà Nội',
  'shippingDistrict': 'Cầu Giấy',
  'shippingWard': 'Dịch Vọng',
  'shippingStreetAddress': '123 Xuân Thủy',
  'note': 'Giao giờ hành chính',
  'items': <Map<String, dynamic>>[_orderItemData()],
  'createdAt': '2025-01-15T10:30:00',
  'cancelledAt': null,
  'deliveredAt': null,
};

Map<String, dynamic> _orderSummaryData() => <String, dynamic>{
  'id': 700,
  'orderCode': 'FV-20250115103000123',
  'status': 'PENDING',
  'paymentStatus': 'UNPAID',
  'total': 3330000.00,
  'itemCount': 2,
  'createdAt': '2025-01-15T10:30:00',
};

Response<Map<String, dynamic>> _envelope(String path, Object data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{
        'success': true,
        'message': 'OK',
        'data': data,
        'timestamp': '2025-01-15T10:30:00',
      },
    );

Response<Map<String, dynamic>> _pageEnvelope(
  String path,
  List<Map<String, dynamic>> content,
) => _envelope(path, <String, dynamic>{
  'content': content,
  'page': 0,
  'size': 20,
  'totalElements': content.length,
  'totalPages': 1,
  'last': true,
});

DioException _errorWith(String errorCode, int statusCode) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/orders'),
  error: AppException(
    message: 'error',
    statusCode: statusCode,
    errorCode: errorCode,
  ),
);

const CouponPreviewRequest _previewRequest = CouponPreviewRequest(
  code: 'SUMMER10',
  cartItemIds: <int>[1, 2],
);

const PlaceOrderRequest _placeRequest = PlaceOrderRequest(
  cartItemIds: <int>[1, 2],
  addressId: 42,
  couponCode: 'SUMMER10',
  note: 'Giao giờ hành chính',
);

@GenerateNiceMocks([MockSpec<Dio>()])
void main() {
  late MockDio dio;
  late OrderRepository repository;

  setUp(() {
    dio = MockDio();
    repository = OrderRepository(dio);
  });

  group('previewCoupon', () {
    test(
      'POSTs the validate path with the body, returns typed preview',
      () async {
        when(
          dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _envelope('/api/v1/coupons/validate', _previewData()),
        );

        final preview = await repository.previewCoupon(_previewRequest);

        final captured = verify(
          dio.post<Map<String, dynamic>>(
            captureAny,
            data: captureAnyNamed('data'),
          ),
        ).captured;
        expect(captured[0], '/api/v1/coupons/validate');
        expect(captured[1], _previewRequest.toJson());
        expect(preview.code, 'SUMMER10');
        expect(preview.name, 'Summer Sale');
        expect(preview.subtotal, 3300000.0);
        expect(preview.discountAmount, 330000.0);
        expect(preview.shippingFee, 30000.0);
        expect(preview.total, 3000000.0);
      },
    );

    test('surfaces COUPON_EXPIRED as a typed AppException', () async {
      when(
        dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('COUPON_EXPIRED', 400));

      await expectLater(
        repository.previewCoupon(_previewRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'COUPON_EXPIRED',
          ),
        ),
      );
    });

    test('surfaces CART_ITEM_FORBIDDEN as a typed AppException', () async {
      when(
        dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('CART_ITEM_FORBIDDEN', 403));

      await expectLater(
        repository.previewCoupon(_previewRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'CART_ITEM_FORBIDDEN',
          ),
        ),
      );
    });
  });

  group('placeOrder', () {
    test('POSTs the orders path with the body, returns typed order', () async {
      when(
        dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _envelope('/api/v1/orders', _orderDetailData()),
      );

      final order = await repository.placeOrder(_placeRequest);

      final captured = verify(
        dio.post<Map<String, dynamic>>(
          captureAny,
          data: captureAnyNamed('data'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/orders');
      expect(captured[1], _placeRequest.toJson());
      expect(order.id, 700);
      expect(order.orderCode, 'FV-20250115103000123');
      expect(order.status, OrderStatus.pending);
      expect(order.paymentMethod, PaymentMethod.cod);
      expect(order.paymentStatus, PaymentStatus.unpaid);
      expect(order.total, 3000000.0);
      expect(order.items, hasLength(1));
      expect(order.items.first.id, 900);
    });

    test(
      'surfaces PRODUCT_VARIANT_INSUFFICIENT_STOCK as an AppException',
      () async {
        when(
          dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
        ).thenThrow(_errorWith('PRODUCT_VARIANT_INSUFFICIENT_STOCK', 400));

        await expectLater(
          repository.placeOrder(_placeRequest),
          throwsA(
            isA<AppException>().having(
              (e) => e.errorCode,
              'errorCode',
              'PRODUCT_VARIANT_INSUFFICIENT_STOCK',
            ),
          ),
        );
      },
    );

    test('surfaces ADDRESS_FORBIDDEN as a typed AppException', () async {
      when(
        dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('ADDRESS_FORBIDDEN', 403));

      await expectLater(
        repository.placeOrder(_placeRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ADDRESS_FORBIDDEN',
          ),
        ),
      );
    });

    test('surfaces COUPON_DISABLED as a typed AppException', () async {
      when(
        dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('COUPON_DISABLED', 400));

      await expectLater(
        repository.placeOrder(_placeRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'COUPON_DISABLED',
          ),
        ),
      );
    });
  });

  group('getMyOrders', () {
    test('GETs the orders path with default paging, returns a page', () async {
      when(
        dio.get<Map<String, dynamic>>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _pageEnvelope('/api/v1/orders', <Map<String, dynamic>>[
          _orderSummaryData(),
        ]),
      );

      final page = await repository.getMyOrders();

      final captured = verify(
        dio.get<Map<String, dynamic>>(
          captureAny,
          queryParameters: captureAnyNamed('queryParameters'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/orders');
      expect(captured[1], <String, dynamic>{'page': 0, 'size': 20});
      expect(page.content, hasLength(1));
      expect(page.content.first.id, 700);
      expect(page.content.first.status, OrderStatus.pending);
      expect(page.content.first.itemCount, 2);
      expect(page.last, isTrue);
    });

    test('encodes the requested page and size', () async {
      when(
        dio.get<Map<String, dynamic>>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _pageEnvelope('/api/v1/orders', <Map<String, dynamic>>[]),
      );

      await repository.getMyOrders(page: 2, size: 5);

      final captured = verify(
        dio.get<Map<String, dynamic>>(
          captureAny,
          queryParameters: captureAnyNamed('queryParameters'),
        ),
      ).captured;
      expect(captured[1], <String, dynamic>{'page': 2, 'size': 5});
    });
  });

  group('getMyOrder', () {
    test('GETs the order id path and returns the typed order', () async {
      when(dio.get<Map<String, dynamic>>(any)).thenAnswer(
        (_) async => _envelope('/api/v1/orders/700', _orderDetailData()),
      );

      final order = await repository.getMyOrder(700);

      final captured = verify(
        dio.get<Map<String, dynamic>>(captureAny),
      ).captured;
      expect(captured[0], '/api/v1/orders/700');
      expect(order.id, 700);
      expect(order.couponCode, 'SUMMER10');
      expect(order.note, 'Giao giờ hành chính');
    });

    test('surfaces ORDER_FORBIDDEN as a typed AppException', () async {
      when(
        dio.get<Map<String, dynamic>>(any),
      ).thenThrow(_errorWith('ORDER_FORBIDDEN', 403));

      await expectLater(
        repository.getMyOrder(700),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ORDER_FORBIDDEN',
          ),
        ),
      );
    });

    test('surfaces ORDER_NOT_FOUND as a typed AppException', () async {
      when(
        dio.get<Map<String, dynamic>>(any),
      ).thenThrow(_errorWith('ORDER_NOT_FOUND', 404));

      await expectLater(
        repository.getMyOrder(999),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ORDER_NOT_FOUND',
          ),
        ),
      );
    });
  });

  group('cancelOrder', () {
    test('POSTs the cancel path and returns the typed order', () async {
      when(dio.post<Map<String, dynamic>>(any)).thenAnswer(
        (_) async => _envelope('/api/v1/orders/700/cancel', _orderDetailData()),
      );

      final order = await repository.cancelOrder(700);

      final captured = verify(
        dio.post<Map<String, dynamic>>(captureAny),
      ).captured;
      expect(captured[0], '/api/v1/orders/700/cancel');
      expect(order.id, 700);
    });

    test('surfaces ORDER_NOT_CANCELLABLE as a typed AppException', () async {
      when(
        dio.post<Map<String, dynamic>>(any),
      ).thenThrow(_errorWith('ORDER_NOT_CANCELLABLE', 409));

      await expectLater(
        repository.cancelOrder(700),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ORDER_NOT_CANCELLABLE',
          ),
        ),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/features/order/models/coupon_preview_request.dart';
import 'package:footverse/features/order/models/coupon_preview_response.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/order_summary_response.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/models/place_order_request.dart';

Map<String, dynamic> _previewJson() => <String, dynamic>{
  'code': 'SUMMER10',
  'name': 'Summer Sale',
  'subtotal': 3300000.00,
  'discountAmount': 330000.00,
  'shippingFee': 30000.00,
  'total': 3000000.00,
};

Map<String, dynamic> _itemJson() => <String, dynamic>{
  'id': 900,
  'productVariantId': 100,
  'productName': 'Air Zoom Pegasus',
  'productImageUrl': 'https://cdn.example.com/p1.jpg',
  'color': 'Black',
  'size': '42',
  'unitPrice': 1650000.00,
  'quantity': 2,
  'lineTotal': 3300000.00,
};

Map<String, dynamic> _summaryJson() => <String, dynamic>{
  'id': 700,
  'orderCode': 'FV-20250115103000123',
  'status': 'PENDING',
  'paymentStatus': 'UNPAID',
  'total': 3330000.00,
  'itemCount': 2,
  'createdAt': '2025-01-15T10:30:00',
};

Map<String, dynamic> _detailJson() => <String, dynamic>{
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
  'items': <Map<String, dynamic>>[_itemJson()],
  'createdAt': '2025-01-15T10:30:00',
  'cancelledAt': null,
  'deliveredAt': null,
};

void main() {
  group('CouponPreviewResponse (dto-spec §14)', () {
    test('maps every field from a real backend payload with a coupon', () {
      final preview = CouponPreviewResponse.fromJson(_previewJson());

      expect(preview.code, 'SUMMER10');
      expect(preview.name, 'Summer Sale');
      expect(preview.subtotal, 3300000.0);
      expect(preview.discountAmount, 330000.0);
      expect(preview.shippingFee, 30000.0);
      expect(preview.total, 3000000.0);
    });

    test('maps a preview without a coupon (null code and name)', () {
      final preview = CouponPreviewResponse.fromJson(
        _previewJson()
          ..['code'] = null
          ..['name'] = null
          ..['discountAmount'] = 0,
      );

      expect(preview.code, isNull);
      expect(preview.name, isNull);
      expect(preview.discountAmount, 0.0);
    });

    test('parses money from JSON numbers and quoted decimal strings', () {
      final fromNumber = CouponPreviewResponse.fromJson(
        _previewJson()..['total'] = 3000000,
      );
      final fromString = CouponPreviewResponse.fromJson(
        _previewJson()..['total'] = '3000000.00',
      );

      expect(fromNumber.total, 3000000.0);
      expect(fromString.total, 3000000.0);
    });
  });

  group('OrderItemResponse (dto-spec §15)', () {
    test('maps every field from a real backend payload', () {
      final item = OrderItemResponse.fromJson(_itemJson());

      expect(item.id, 900);
      expect(item.productVariantId, 100);
      expect(item.productName, 'Air Zoom Pegasus');
      expect(item.productImageUrl, 'https://cdn.example.com/p1.jpg');
      expect(item.color, 'Black');
      expect(item.size, '42');
      expect(item.unitPrice, 1650000.0);
      expect(item.quantity, 2);
      expect(item.lineTotal, 3300000.0);
    });

    test('accepts a null productImageUrl', () {
      final item = OrderItemResponse.fromJson(
        _itemJson()..['productImageUrl'] = null,
      );

      expect(item.productImageUrl, isNull);
    });

    test('parses money from a quoted decimal string', () {
      final item = OrderItemResponse.fromJson(
        _itemJson()
          ..['unitPrice'] = '1650000.00'
          ..['lineTotal'] = '3300000.00',
      );

      expect(item.unitPrice, 1650000.0);
      expect(item.lineTotal, 3300000.0);
    });
  });

  group('OrderSummaryResponse (dto-spec §15)', () {
    test('maps every field from a real backend payload', () {
      final summary = OrderSummaryResponse.fromJson(_summaryJson());

      expect(summary.id, 700);
      expect(summary.orderCode, 'FV-20250115103000123');
      expect(summary.status, OrderStatus.pending);
      expect(summary.paymentStatus, PaymentStatus.unpaid);
      expect(summary.total, 3330000.0);
      expect(summary.itemCount, 2);
      expect(summary.createdAt, DateTime.parse('2025-01-15T10:30:00'));
    });

    test('maps every OrderStatus wire value', () {
      const wireToEnum = <String, OrderStatus>{
        'PENDING': OrderStatus.pending,
        'CONFIRMED': OrderStatus.confirmed,
        'SHIPPING': OrderStatus.shipping,
        'DELIVERED': OrderStatus.delivered,
        'CANCELLED': OrderStatus.cancelled,
      };

      wireToEnum.forEach((wire, expected) {
        final summary = OrderSummaryResponse.fromJson(
          _summaryJson()..['status'] = wire,
        );

        expect(summary.status, expected);
      });
    });

    test('maps the PAID payment status', () {
      final summary = OrderSummaryResponse.fromJson(
        _summaryJson()..['paymentStatus'] = 'PAID',
      );

      expect(summary.paymentStatus, PaymentStatus.paid);
    });
  });

  group('OrderDetailResponse (dto-spec §15)', () {
    test('maps every field and nested items from a real backend payload', () {
      final order = OrderDetailResponse.fromJson(_detailJson());

      expect(order.id, 700);
      expect(order.orderCode, 'FV-20250115103000123');
      expect(order.status, OrderStatus.pending);
      expect(order.paymentMethod, PaymentMethod.cod);
      expect(order.paymentStatus, PaymentStatus.unpaid);
      expect(order.subtotal, 3300000.0);
      expect(order.discountAmount, 330000.0);
      expect(order.shippingFee, 30000.0);
      expect(order.total, 3000000.0);
      expect(order.couponCode, 'SUMMER10');
      expect(order.shippingRecipientName, 'Nguyen Van A');
      expect(order.shippingRecipientPhone, '0901234567');
      expect(order.shippingProvince, 'Hà Nội');
      expect(order.shippingDistrict, 'Cầu Giấy');
      expect(order.shippingWard, 'Dịch Vọng');
      expect(order.shippingStreetAddress, '123 Xuân Thủy');
      expect(order.note, 'Giao giờ hành chính');
      expect(order.items, hasLength(1));
      expect(order.items.first.id, 900);
      expect(order.createdAt, DateTime.parse('2025-01-15T10:30:00'));
      expect(order.cancelledAt, isNull);
      expect(order.deliveredAt, isNull);
    });

    test('accepts null couponCode and note', () {
      final order = OrderDetailResponse.fromJson(
        _detailJson()
          ..['couponCode'] = null
          ..['note'] = null,
      );

      expect(order.couponCode, isNull);
      expect(order.note, isNull);
    });

    test('maps cancelledAt and deliveredAt when present', () {
      final order = OrderDetailResponse.fromJson(
        _detailJson()
          ..['status'] = 'CANCELLED'
          ..['cancelledAt'] = '2025-01-16T09:00:00'
          ..['deliveredAt'] = '2025-01-18T14:00:00',
      );

      expect(order.status, OrderStatus.cancelled);
      expect(order.cancelledAt, DateTime.parse('2025-01-16T09:00:00'));
      expect(order.deliveredAt, DateTime.parse('2025-01-18T14:00:00'));
    });
  });

  group('CouponPreviewRequest (dto-spec §14, validation-spec §9)', () {
    test('serializes the code and cart item ids', () {
      const request = CouponPreviewRequest(
        code: 'SUMMER10',
        cartItemIds: <int>[1, 2, 3],
      );

      expect(request.toJson(), <String, dynamic>{
        'code': 'SUMMER10',
        'cartItemIds': <int>[1, 2, 3],
      });
    });

    test('omits the optional code when it is not set', () {
      const request = CouponPreviewRequest(cartItemIds: <int>[1, 2]);

      expect(request.toJson().containsKey('code'), isFalse);
      expect(request.toJson()['cartItemIds'], <int>[1, 2]);
    });

    test('keeps duplicate cart item ids as entered (server validates)', () {
      const request = CouponPreviewRequest(cartItemIds: <int>[1, 1, 2]);

      expect(request.toJson()['cartItemIds'], <int>[1, 1, 2]);
    });
  });

  group('PlaceOrderRequest (dto-spec §15, validation-spec §10)', () {
    test('serializes every write field', () {
      const request = PlaceOrderRequest(
        cartItemIds: <int>[1, 2],
        addressId: 42,
        couponCode: 'SUMMER10',
        note: 'Giao giờ hành chính',
      );

      expect(request.toJson(), <String, dynamic>{
        'cartItemIds': <int>[1, 2],
        'addressId': 42,
        'couponCode': 'SUMMER10',
        'note': 'Giao giờ hành chính',
      });
    });

    test('omits the optional couponCode and note when not set', () {
      const request = PlaceOrderRequest(cartItemIds: <int>[1], addressId: 42);

      final json = request.toJson();
      expect(json.containsKey('couponCode'), isFalse);
      expect(json.containsKey('note'), isFalse);
      expect(json, <String, dynamic>{
        'cartItemIds': <int>[1],
        'addressId': 42,
      });
    });

    test('keeps duplicate cart item ids as entered (server validates)', () {
      const request = PlaceOrderRequest(
        cartItemIds: <int>[1, 1, 2],
        addressId: 42,
      );

      expect(request.toJson()['cartItemIds'], <int>[1, 1, 2]);
    });
  });
}

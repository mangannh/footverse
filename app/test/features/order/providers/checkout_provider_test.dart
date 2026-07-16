import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/address/models/address_response.dart';
import 'package:footverse/features/address/repositories/address_repository.dart';
import 'package:footverse/features/order/models/coupon_preview_response.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/providers/checkout_provider.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'checkout_provider_test.mocks.dart';

const List<int> _cartItemIds = <int>[1, 2];

AddressResponse _address({required int id, bool isDefault = false}) =>
    AddressResponse(
      id: id,
      recipientName: 'Recipient $id',
      recipientPhone: '0901234567',
      province: 'Hà Nội',
      district: 'Cầu Giấy',
      ward: 'Dịch Vọng',
      streetAddress: '123 Xuân Thủy',
      isDefault: isDefault,
    );

CouponPreviewResponse _preview({
  String? code,
  String? name,
  double subtotal = 100,
  double discountAmount = 0,
  double shippingFee = 30,
  double total = 130,
}) => CouponPreviewResponse(
  code: code,
  name: name,
  subtotal: subtotal,
  discountAmount: discountAmount,
  shippingFee: shippingFee,
  total: total,
);

OrderDetailResponse _order({int id = 700}) => OrderDetailResponse(
  id: id,
  orderCode: 'FV-$id',
  status: OrderStatus.pending,
  paymentMethod: PaymentMethod.cod,
  paymentStatus: PaymentStatus.unpaid,
  subtotal: 100,
  discountAmount: 0,
  shippingFee: 30,
  total: 130,
  shippingRecipientName: 'Recipient',
  shippingRecipientPhone: '0901234567',
  shippingProvince: 'Hà Nội',
  shippingDistrict: 'Cầu Giấy',
  shippingWard: 'Dịch Vọng',
  shippingStreetAddress: '123 Xuân Thủy',
  items: const <OrderItemResponse>[],
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
);

const AppException _couponExpired = AppException(
  message: 'Coupon is not valid at this time',
  statusCode: 400,
  errorCode: 'COUPON_EXPIRED',
);

const AppException _insufficientStock = AppException(
  message: 'Requested quantity exceeds available stock',
  statusCode: 400,
  errorCode: 'PRODUCT_VARIANT_INSUFFICIENT_STOCK',
);

const AppException _networkError = AppException.network(
  message: 'Unable to reach the server.',
);

@GenerateNiceMocks([MockSpec<OrderRepository>(), MockSpec<AddressRepository>()])
void main() {
  late MockOrderRepository orderRepository;
  late MockAddressRepository addressRepository;
  late CheckoutProvider provider;

  setUp(() {
    orderRepository = MockOrderRepository();
    addressRepository = MockAddressRepository();
    provider = CheckoutProvider(
      orderRepository,
      addressRepository,
      _cartItemIds,
    );
  });

  void stubPreview(CouponPreviewResponse result) {
    when(orderRepository.previewCoupon(any)).thenAnswer((_) async => result);
  }

  group('load', () {
    test(
      'previews the selected items and selects the default address',
      () async {
        when(addressRepository.getAddresses()).thenAnswer(
          (_) async => <AddressResponse>[
            _address(id: 1),
            _address(id: 2, isDefault: true),
          ],
        );
        stubPreview(_preview());

        await provider.load();

        expect(provider.status, CheckoutStatus.ready);
        expect(provider.selectedAddress?.id, 2);
        expect(provider.preview, isNotNull);
        expect(provider.appliedCouponCode, isNull);
        expect(provider.canPlaceOrder, isTrue);

        final request = verify(
          orderRepository.previewCoupon(captureAny),
        ).captured.single;
        expect(request.code, isNull);
        expect(request.cartItemIds, _cartItemIds);
      },
    );

    test('falls back to the first address when none is default', () async {
      when(addressRepository.getAddresses()).thenAnswer(
        (_) async => <AddressResponse>[_address(id: 5), _address(id: 6)],
      );
      stubPreview(_preview());

      await provider.load();

      expect(provider.selectedAddress?.id, 5);
    });

    test(
      'with no addresses still previews but cannot place an order',
      () async {
        when(
          addressRepository.getAddresses(),
        ).thenAnswer((_) async => const <AddressResponse>[]);
        stubPreview(_preview());

        await provider.load();

        expect(provider.status, CheckoutStatus.ready);
        expect(provider.selectedAddress, isNull);
        expect(provider.preview, isNotNull);
        expect(provider.canPlaceOrder, isFalse);
      },
    );

    test('a failed load moves to error and preserves the exception', () async {
      when(addressRepository.getAddresses()).thenThrow(_networkError);

      await provider.load();

      expect(provider.status, CheckoutStatus.error);
      expect(provider.error, same(_networkError));
    });
  });

  group('coupon', () {
    test('apply updates the preview and the applied code', () async {
      when(addressRepository.getAddresses()).thenAnswer(
        (_) async => <AddressResponse>[_address(id: 1, isDefault: true)],
      );
      stubPreview(_preview());
      await provider.load();

      stubPreview(
        _preview(
          code: 'SUMMER10',
          name: 'Summer',
          discountAmount: 10,
          total: 120,
        ),
      );
      await provider.applyCoupon('SUMMER10');

      expect(provider.appliedCouponCode, 'SUMMER10');
      expect(provider.preview?.code, 'SUMMER10');
      expect(provider.preview?.discountAmount, 10);

      final request = verify(
        orderRepository.previewCoupon(captureAny),
      ).captured.last;
      expect(request.code, 'SUMMER10');
    });

    test(
      'a rejected coupon rethrows and keeps the last valid preview',
      () async {
        when(addressRepository.getAddresses()).thenAnswer(
          (_) async => <AddressResponse>[_address(id: 1, isDefault: true)],
        );
        final valid = _preview();
        stubPreview(valid);
        await provider.load();

        when(orderRepository.previewCoupon(any)).thenThrow(_couponExpired);

        await expectLater(
          provider.applyCoupon('BAD'),
          throwsA(
            isA<AppException>().having(
              (e) => e.errorCode,
              'errorCode',
              'COUPON_EXPIRED',
            ),
          ),
        );
        expect(provider.preview, same(valid));
        expect(provider.appliedCouponCode, isNull);
        expect(provider.isPreviewing, isFalse);
      },
    );

    test(
      'clear re-previews with no code and clears the applied code',
      () async {
        when(addressRepository.getAddresses()).thenAnswer(
          (_) async => <AddressResponse>[_address(id: 1, isDefault: true)],
        );
        stubPreview(_preview());
        await provider.load();
        stubPreview(_preview(code: 'X', discountAmount: 10, total: 120));
        await provider.applyCoupon('X');
        expect(provider.appliedCouponCode, 'X');

        stubPreview(_preview());
        await provider.clearCoupon();

        expect(provider.appliedCouponCode, isNull);
        expect(provider.preview?.code, isNull);
        final request = verify(
          orderRepository.previewCoupon(captureAny),
        ).captured.last;
        expect(request.code, isNull);
      },
    );

    test('a second preview while one is in flight is ignored', () async {
      when(addressRepository.getAddresses()).thenAnswer(
        (_) async => <AddressResponse>[_address(id: 1, isDefault: true)],
      );
      stubPreview(_preview());
      await provider.load();

      final completer = Completer<CouponPreviewResponse>();
      when(
        orderRepository.previewCoupon(any),
      ).thenAnswer((_) => completer.future);

      final first = provider.applyCoupon('A');
      final second = provider.applyCoupon('B');
      expect(provider.isPreviewing, isTrue);

      completer.complete(_preview(code: 'A'));
      await first;
      await second;

      // One call during load + one for 'A'; 'B' was ignored (single-flight).
      verify(orderRepository.previewCoupon(any)).called(2);
      expect(provider.appliedCouponCode, 'A');
      expect(provider.isPreviewing, isFalse);
    });
  });

  group('placeOrder', () {
    Future<void> loadReady() async {
      when(addressRepository.getAddresses()).thenAnswer(
        (_) async => <AddressResponse>[_address(id: 9, isDefault: true)],
      );
      stubPreview(_preview());
      await provider.load();
    }

    test('places the order and returns the created detail', () async {
      await loadReady();
      when(orderRepository.placeOrder(any)).thenAnswer((_) async => _order());

      final order = await provider.placeOrder();

      expect(order?.id, 700);
      final request = verify(
        orderRepository.placeOrder(captureAny),
      ).captured.single;
      expect(request.cartItemIds, _cartItemIds);
      expect(request.addressId, 9);
      expect(request.couponCode, isNull);
      expect(request.note, isNull);
      expect(provider.isPlacing, isFalse);
    });

    test('sends the applied coupon and the note', () async {
      await loadReady();
      stubPreview(_preview(code: 'X', discountAmount: 10, total: 120));
      await provider.applyCoupon('X');
      provider.setNote('Giao giờ hành chính');
      when(orderRepository.placeOrder(any)).thenAnswer((_) async => _order());

      await provider.placeOrder();

      final request = verify(
        orderRepository.placeOrder(captureAny),
      ).captured.single;
      expect(request.couponCode, 'X');
      expect(request.note, 'Giao giờ hành chính');
    });

    test('rethrows a server rejection and places no order', () async {
      await loadReady();
      when(orderRepository.placeOrder(any)).thenThrow(_insufficientStock);

      await expectLater(
        provider.placeOrder(),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'PRODUCT_VARIANT_INSUFFICIENT_STOCK',
          ),
        ),
      );
      expect(provider.isPlacing, isFalse);
    });

    test(
      'returns null and calls nothing when no address is selected',
      () async {
        when(
          addressRepository.getAddresses(),
        ).thenAnswer((_) async => const <AddressResponse>[]);
        stubPreview(_preview());
        await provider.load();

        final order = await provider.placeOrder();

        expect(order, isNull);
        verifyNever(orderRepository.placeOrder(any));
      },
    );

    test('a second place while one is in flight is ignored', () async {
      await loadReady();
      final completer = Completer<OrderDetailResponse>();
      when(orderRepository.placeOrder(any)).thenAnswer((_) => completer.future);

      final first = provider.placeOrder();
      final second = provider.placeOrder();
      expect(provider.isPlacing, isTrue);
      expect(await second, isNull);

      completer.complete(_order());
      expect((await first)?.id, 700);

      verify(orderRepository.placeOrder(any)).called(1);
      expect(provider.isPlacing, isFalse);
    });
  });
}

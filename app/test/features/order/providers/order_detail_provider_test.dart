import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/providers/order_detail_provider.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'order_detail_provider_test.mocks.dart';

const int _orderId = 700;

OrderDetailResponse _order({
  OrderStatus status = OrderStatus.pending,
  DateTime? cancelledAt,
}) => OrderDetailResponse(
  id: _orderId,
  orderCode: 'FV-$_orderId',
  status: status,
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
  cancelledAt: cancelledAt,
);

const AppException _notCancellable = AppException(
  message: 'This order can no longer be cancelled',
  statusCode: 409,
  errorCode: 'ORDER_NOT_CANCELLABLE',
);

const AppException _forbidden = AppException(
  message: 'You do not have access to this order',
  statusCode: 403,
  errorCode: 'ORDER_FORBIDDEN',
);

const AppException _notFound = AppException(
  message: 'Order not found',
  statusCode: 404,
  errorCode: 'ORDER_NOT_FOUND',
);

@GenerateNiceMocks([MockSpec<OrderRepository>()])
void main() {
  late MockOrderRepository orderRepository;
  late OrderDetailProvider provider;

  setUp(() {
    orderRepository = MockOrderRepository();
    provider = OrderDetailProvider(orderRepository, _orderId);
  });

  group('load', () {
    test('loads the order and moves to ready', () async {
      when(
        orderRepository.getMyOrder(_orderId),
      ).thenAnswer((_) async => _order());

      await provider.load();

      expect(provider.status, OrderDetailStatus.ready);
      expect(provider.order?.orderCode, 'FV-$_orderId');
      expect(provider.error, isNull);
      verify(orderRepository.getMyOrder(_orderId)).called(1);
    });

    test('a failed load moves to error and preserves the exception', () async {
      when(orderRepository.getMyOrder(_orderId)).thenThrow(_forbidden);

      await provider.load();

      expect(provider.status, OrderDetailStatus.error);
      expect(provider.order, isNull);
      expect(provider.error?.errorCode, 'ORDER_FORBIDDEN');
    });

    test('surfaces a not-found order as the error state', () async {
      when(orderRepository.getMyOrder(_orderId)).thenThrow(_notFound);

      await provider.load();

      expect(provider.status, OrderDetailStatus.error);
      expect(provider.error?.errorCode, 'ORDER_NOT_FOUND');
    });

    test('retry reloads the order after an error', () async {
      when(orderRepository.getMyOrder(_orderId)).thenThrow(_notFound);
      await provider.load();
      expect(provider.status, OrderDetailStatus.error);

      when(
        orderRepository.getMyOrder(_orderId),
      ).thenAnswer((_) async => _order());
      await provider.retry();

      expect(provider.status, OrderDetailStatus.ready);
      expect(provider.order, isNotNull);
      expect(provider.error, isNull);
    });

    test('discards a stale load response superseded by a newer load', () async {
      // Request 1 hangs in flight.
      final gate = Completer<OrderDetailResponse>();
      when(orderRepository.getMyOrder(_orderId)).thenAnswer((_) => gate.future);
      final stale = provider.load();

      // Request 2 (e.g. a retry) supersedes it and completes with a different
      // order — the cancelled one wins.
      final fresh = _order(status: OrderStatus.cancelled);
      when(orderRepository.getMyOrder(_orderId)).thenAnswer((_) async => fresh);
      await provider.retry();
      expect(provider.order?.status, OrderStatus.cancelled);

      // The stale request-1 response now arrives and must be ignored (the
      // request-generation guard), leaving the newer state intact.
      gate.complete(_order());
      await stale;

      expect(provider.order?.status, OrderStatus.cancelled);
      expect(provider.status, OrderDetailStatus.ready);
    });
  });

  group('cancel', () {
    Future<void> loadPending() async {
      when(
        orderRepository.getMyOrder(_orderId),
      ).thenAnswer((_) async => _order());
      await provider.load();
    }

    test('replaces the whole state with the cancelled order', () async {
      await loadPending();
      final cancelled = _order(
        status: OrderStatus.cancelled,
        cancelledAt: DateTime.parse('2025-01-16T09:00:00'),
      );
      when(
        orderRepository.cancelOrder(_orderId),
      ).thenAnswer((_) async => cancelled);

      await provider.cancel();

      expect(provider.order?.status, OrderStatus.cancelled);
      expect(provider.order?.cancelledAt, isNotNull);
      expect(provider.isCancelling, isFalse);
      verify(orderRepository.cancelOrder(_orderId)).called(1);
    });

    test('a rejected cancel rethrows and keeps the order unchanged', () async {
      await loadPending();
      when(orderRepository.cancelOrder(_orderId)).thenThrow(_notCancellable);

      await expectLater(
        provider.cancel(),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ORDER_NOT_CANCELLABLE',
          ),
        ),
      );

      expect(provider.order?.status, OrderStatus.pending);
      expect(provider.isCancelling, isFalse);
    });

    test('a second cancel while one is in flight is ignored', () async {
      await loadPending();
      final completer = Completer<OrderDetailResponse>();
      when(
        orderRepository.cancelOrder(_orderId),
      ).thenAnswer((_) => completer.future);

      final first = provider.cancel();
      final second = provider.cancel();
      expect(provider.isCancelling, isTrue);

      completer.complete(_order(status: OrderStatus.cancelled));
      await first;
      await second;

      verify(orderRepository.cancelOrder(_orderId)).called(1);
      expect(provider.order?.status, OrderStatus.cancelled);
      expect(provider.isCancelling, isFalse);
    });
  });

  group('lifecycle', () {
    test('a load that completes after dispose does not throw', () async {
      final gate = Completer<OrderDetailResponse>();
      when(orderRepository.getMyOrder(_orderId)).thenAnswer((_) => gate.future);

      final pending = provider.load();
      provider.dispose();
      gate.complete(_order());

      await expectLater(pending, completes);
    });
  });
}

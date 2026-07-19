import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/models/payment_url_response.dart';
import 'package:footverse/features/order/providers/payment_provider.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'payment_provider_test.mocks.dart';

const int _orderId = 700;

PaymentUrlResponse _paymentUrl() => PaymentUrlResponse(
  paymentUrl: 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?a=1',
  txnRef: 'VNP-700',
  expiresAt: DateTime.parse('2025-01-15T10:45:00'),
);

OrderDetailResponse _order({required PaymentStatus paymentStatus}) =>
    OrderDetailResponse(
      id: _orderId,
      orderCode: 'FV-700',
      status: OrderStatus.pending,
      paymentMethod: PaymentMethod.vnpay,
      paymentStatus: paymentStatus,
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

const AppException _paymentNotApplicable = AppException(
  message: 'Payment is not applicable for this order',
  statusCode: 409,
  errorCode: 'PAYMENT_NOT_APPLICABLE',
);

const AppException _networkError = AppException.network(
  message: 'Unable to reach the server.',
);

@GenerateNiceMocks([MockSpec<OrderRepository>()])
void main() {
  late MockOrderRepository repository;
  late PaymentProvider provider;

  setUp(() {
    repository = MockOrderRepository();
    provider = PaymentProvider(repository, _orderId);
  });

  group('requestPaymentUrl', () {
    test('moves loading → success and exposes the signed URL', () async {
      final statuses = <PaymentFlowStatus>[];
      provider.addListener(() => statuses.add(provider.status));
      when(
        repository.createPaymentUrl(_orderId),
      ).thenAnswer((_) async => _paymentUrl());

      await provider.requestPaymentUrl();

      expect(statuses, <PaymentFlowStatus>[
        PaymentFlowStatus.loading,
        PaymentFlowStatus.success,
      ]);
      expect(provider.paymentUrl?.txnRef, 'VNP-700');
      verify(repository.createPaymentUrl(_orderId)).called(1);
    });

    test(
      'a server rejection moves to error and rethrows the AppException',
      () async {
        when(
          repository.createPaymentUrl(_orderId),
        ).thenThrow(_paymentNotApplicable);

        await expectLater(
          provider.requestPaymentUrl(),
          throwsA(
            isA<AppException>().having(
              (e) => e.errorCode,
              'errorCode',
              'PAYMENT_NOT_APPLICABLE',
            ),
          ),
        );

        expect(provider.status, PaymentFlowStatus.error);
        expect(provider.error, same(_paymentNotApplicable));
        expect(provider.paymentUrl, isNull);
      },
    );

    test('a second call while one is in flight is ignored', () async {
      final completer = Completer<PaymentUrlResponse>();
      when(
        repository.createPaymentUrl(_orderId),
      ).thenAnswer((_) => completer.future);

      final first = provider.requestPaymentUrl();
      final second = provider.requestPaymentUrl();
      expect(provider.status, PaymentFlowStatus.loading);

      completer.complete(_paymentUrl());
      await first;
      await second;

      verify(repository.createPaymentUrl(_orderId)).called(1);
      expect(provider.status, PaymentFlowStatus.success);
    });
  });

  group('reloadOrder', () {
    test(
      'reloads through getMyOrder and exposes the server order as-is',
      () async {
        when(
          repository.getMyOrder(_orderId),
        ).thenAnswer((_) async => _order(paymentStatus: PaymentStatus.paid));

        await provider.reloadOrder();

        expect(provider.order?.paymentStatus, PaymentStatus.paid);
        verify(repository.getMyOrder(_orderId)).called(1);
      },
    );

    test('anti-spoofing: a "return reached" reload that is still UNPAID on the '
        'server renders as UNPAID, never inferred as paid', () async {
      when(
        repository.getMyOrder(_orderId),
      ).thenAnswer((_) async => _order(paymentStatus: PaymentStatus.unpaid));

      // Simulates the WebView's return-URL signal — the provider is told
      // nothing about the gateway's outcome, only to reload.
      await provider.reloadOrder();

      expect(provider.order?.paymentStatus, PaymentStatus.unpaid);
    });

    test('a failed reload moves to error and rethrows', () async {
      when(repository.getMyOrder(_orderId)).thenThrow(_networkError);

      await expectLater(provider.reloadOrder(), throwsA(isA<AppException>()));

      expect(provider.status, PaymentFlowStatus.error);
      expect(provider.order, isNull);
    });

    test('a second call while one is in flight is ignored', () async {
      final completer = Completer<OrderDetailResponse>();
      when(repository.getMyOrder(_orderId)).thenAnswer((_) => completer.future);

      final first = provider.reloadOrder();
      final second = provider.reloadOrder();
      expect(provider.status, PaymentFlowStatus.loading);

      completer.complete(_order(paymentStatus: PaymentStatus.paid));
      await first;
      await second;

      verify(repository.getMyOrder(_orderId)).called(1);
    });
  });

  test('never reads any gateway parameter — reloadOrder takes none and the '
      'server order alone drives the exposed state', () async {
    when(
      repository.getMyOrder(_orderId),
    ).thenAnswer((_) async => _order(paymentStatus: PaymentStatus.paid));

    await provider.reloadOrder();

    // The only inputs to reloadOrder are the constructor-supplied orderId
    // and the repository response — no vnp_* parameter is ever accepted.
    verifyNever(repository.createPaymentUrl(any));
    expect(provider.order?.paymentStatus, PaymentStatus.paid);
  });
}

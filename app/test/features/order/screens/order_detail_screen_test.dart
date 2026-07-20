import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_error_state.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';
import 'package:footverse/core/widgets/price_text.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:footverse/features/order/screens/order_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'order_detail_screen_test.mocks.dart';

OrderDetailResponse _order({
  OrderStatus status = OrderStatus.pending,
  PaymentMethod paymentMethod = PaymentMethod.cod,
  PaymentStatus paymentStatus = PaymentStatus.unpaid,
}) => OrderDetailResponse(
  id: 700,
  orderCode: 'FV-700',
  status: status,
  paymentMethod: paymentMethod,
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
  items: const <OrderItemResponse>[
    OrderItemResponse(
      id: 1,
      productVariantId: 10,
      productId: 55,
      productName: 'FootVerse Runner',
      color: 'Black',
      size: '42',
      unitPrice: 100,
      quantity: 1,
      lineTotal: 100,
    ),
  ],
  createdAt: DateTime(2026, 7, 19, 10, 30),
);

GoRouter _router(OrderRepository repository) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) =>
          OrderDetailScreen(orderId: 700, orderRepository: repository),
    ),
    GoRoute(
      path: '/products/:id',
      name: AppRoute.productDetail,
      builder: (context, state) =>
          Scaffold(body: Text('product-detail:${state.pathParameters['id']}')),
    ),
  ],
);

Future<void> _pumpScreen(
  WidgetTester tester,
  MockOrderRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _router(repository),
    ),
  );
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<OrderRepository>()])
void main() {
  late MockOrderRepository repository;

  setUp(() {
    repository = MockOrderRepository();
  });

  testWidgets(
    'the status banner is the first element on the screen — above the '
    'order code',
    (tester) async {
      when(
        repository.getMyOrder(any),
      ).thenAnswer((_) async => _order(status: OrderStatus.shipping));

      await _pumpScreen(tester, repository);

      // "Shipping" also labels the address card title and the summary's
      // shipping-fee row; the banner is the first occurrence in tree order.
      final statusY = tester.getTopLeft(find.text('Shipping').first).dy;
      final orderCodeY = tester.getTopLeft(find.text('FV-700')).dy;
      expect(statusY, lessThan(orderCodeY));
    },
  );

  testWidgets(
    'renders every amount through PriceText — no raw money on screen',
    (tester) async {
      when(repository.getMyOrder(any)).thenAnswer((_) async => _order());

      await _pumpScreen(tester, repository);

      // unitPrice + lineTotal (item) + subtotal + discount + shipping + total.
      expect(find.byType(PriceText), findsNWidgets(6));
      expect(find.text('130.0'), findsNothing);
      expect(find.text('100.0'), findsNothing);
    },
  );

  testWidgets('shows dates via AppDateFormat — no raw ISO timestamp', (
    tester,
  ) async {
    when(repository.getMyOrder(any)).thenAnswer((_) async => _order());

    await _pumpScreen(tester, repository);

    expect(find.text('19 Jul 2026'), findsOneWidget);
  });

  testWidgets(
    'shows Cancel Order for a pending order and requires confirmation',
    (tester) async {
      when(
        repository.getMyOrder(any),
      ).thenAnswer((_) async => _order(status: OrderStatus.pending));
      when(
        repository.cancelOrder(any),
      ).thenAnswer((_) async => _order(status: OrderStatus.cancelled));

      await _pumpScreen(tester, repository);

      expect(find.text('Cancel Order'), findsOneWidget);

      await tester.tap(find.text('Cancel Order'));
      await tester.pumpAndSettle();

      // The existing confirmation dialog appears — cancelOrder is not yet
      // called.
      expect(
        find.text(
          'Are you sure you want to cancel this order? '
          'This cannot be undone.',
        ),
        findsOneWidget,
      );
      verifyNever(repository.cancelOrder(any));

      await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
      await tester.pumpAndSettle();

      verify(repository.cancelOrder(700)).called(1);
    },
  );

  testWidgets(
    'hides Cancel entirely (not disabled) once the order is delivered',
    (tester) async {
      when(
        repository.getMyOrder(any),
      ).thenAnswer((_) async => _order(status: OrderStatus.delivered));

      await _pumpScreen(tester, repository);

      expect(find.text('Cancel Order'), findsNothing);
    },
  );

  testWidgets('shows "Review this product" only on a delivered order', (
    tester,
  ) async {
    when(
      repository.getMyOrder(any),
    ).thenAnswer((_) async => _order(status: OrderStatus.delivered));

    await _pumpScreen(tester, repository);

    expect(find.text('Review this product'), findsOneWidget);

    await tester.tap(find.text('Review this product'));
    await tester.pumpAndSettle();

    expect(find.text('product-detail:55'), findsOneWidget);
  });

  testWidgets('does not show "Review this product" on a non-delivered order', (
    tester,
  ) async {
    when(
      repository.getMyOrder(any),
    ).thenAnswer((_) async => _order(status: OrderStatus.shipping));

    await _pumpScreen(tester, repository);

    expect(find.text('Review this product'), findsNothing);
  });

  testWidgets('shows Pay now only for a PENDING/UNPAID/VNPay order', (
    tester,
  ) async {
    when(repository.getMyOrder(any)).thenAnswer(
      (_) async => _order(
        status: OrderStatus.pending,
        paymentMethod: PaymentMethod.vnpay,
        paymentStatus: PaymentStatus.unpaid,
      ),
    );

    await _pumpScreen(tester, repository);

    expect(find.text('Pay now'), findsOneWidget);
  });

  testWidgets(
    'shows a skeleton while the order loads — never a centred spinner',
    (tester) async {
      final completer = Completer<OrderDetailResponse>();
      when(repository.getMyOrder(any)).thenAnswer((_) => completer.future);

      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: _router(repository),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(ListTileSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(_order());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows AppErrorState on a failed load, with a working retry', (
    tester,
  ) async {
    var callCount = 0;
    when(repository.getMyOrder(any)).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const AppException(message: 'Something broke');
      }
      return _order();
    });

    await _pumpScreen(tester, repository);

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Something broke'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsNothing);
    expect(find.text('FV-700'), findsOneWidget);
  });
}

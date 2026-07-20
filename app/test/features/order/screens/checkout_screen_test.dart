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
import 'package:footverse/core/widgets/section_header.dart';
import 'package:footverse/features/address/models/address_response.dart';
import 'package:footverse/features/address/repositories/address_repository.dart';
import 'package:footverse/features/cart/models/cart_response.dart';
import 'package:footverse/features/cart/providers/cart_provider.dart';
import 'package:footverse/features/cart/repositories/cart_repository.dart';
import 'package:footverse/features/order/models/coupon_preview_request.dart';
import 'package:footverse/features/order/models/coupon_preview_response.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/models/place_order_request.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:footverse/features/order/screens/checkout_screen.dart';
import 'package:footverse/features/order/screens/order_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'checkout_screen_test.mocks.dart';

AddressResponse _address() => const AddressResponse(
  id: 1,
  recipientName: 'Recipient',
  recipientPhone: '0901234567',
  province: 'Hà Nội',
  district: 'Cầu Giấy',
  ward: 'Dịch Vọng',
  streetAddress: '123 Xuân Thủy',
  isDefault: true,
);

CouponPreviewResponse _preview() => const CouponPreviewResponse(
  subtotal: 100,
  discountAmount: 0,
  shippingFee: 30,
  total: 130,
);

CouponPreviewResponse _previewWithCoupon(String code) => CouponPreviewResponse(
  code: code,
  name: 'Sale',
  subtotal: 100,
  discountAmount: 20,
  shippingFee: 30,
  total: 110,
);

OrderDetailResponse _order({PaymentMethod paymentMethod = PaymentMethod.cod}) =>
    OrderDetailResponse(
      id: 700,
      orderCode: 'FV-700',
      status: OrderStatus.pending,
      paymentMethod: paymentMethod,
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

CartResponse _cart() =>
    const CartResponse(items: [], subtotal: 0, itemCount: 0);

GoRouter _router(
  OrderRepository orderRepository,
  AddressRepository addressRepository,
) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => CheckoutScreen(
        orderRepository: orderRepository,
        addressRepository: addressRepository,
        cartItemIds: const <int>[1, 2],
      ),
      routes: <RouteBase>[
        GoRoute(
          path: 'payment/:id',
          name: AppRoute.paymentWebview,
          builder: (context, state) =>
              const Scaffold(body: Text('payment-webview-placeholder')),
        ),
      ],
    ),
    GoRoute(
      path: '/orders/:id',
      name: AppRoute.orderDetail,
      builder: (context, state) => OrderDetailScreen(
        orderId: int.parse(state.pathParameters['id']!),
        orderRepository: orderRepository,
      ),
    ),
  ],
);

Future<void> _pumpCheckout(
  WidgetTester tester,
  OrderRepository orderRepository,
  AddressRepository addressRepository,
  CartRepository cartRepository,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ChangeNotifierProvider<CartProvider>.value(
      value: CartProvider(cartRepository),
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router(orderRepository, addressRepository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([
  MockSpec<OrderRepository>(),
  MockSpec<AddressRepository>(),
  MockSpec<CartRepository>(),
])
void main() {
  testWidgets('placing an order reloads the cart and opens the order detail', (
    tester,
  ) async {
    final orderRepository = MockOrderRepository();
    final addressRepository = MockAddressRepository();
    final cartRepository = MockCartRepository();
    when(
      addressRepository.getAddresses(),
    ).thenAnswer((_) async => <AddressResponse>[_address()]);
    when(
      orderRepository.previewCoupon(any),
    ).thenAnswer((_) async => _preview());
    when(orderRepository.placeOrder(any)).thenAnswer((_) async => _order());
    // The order-detail screen loads the order on mount after navigation.
    when(orderRepository.getMyOrder(any)).thenAnswer((_) async => _order());
    when(cartRepository.getCart()).thenAnswer((_) async => _cart());

    await _pumpCheckout(
      tester,
      orderRepository,
      addressRepository,
      cartRepository,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Place Order'));
    await tester.pumpAndSettle();

    verify(orderRepository.placeOrder(any)).called(1);
    // The cart is refreshed through its own public load() → getCart().
    verify(cartRepository.getCart()).called(1);
    // Navigated to the new order's detail.
    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.text('FV-700'), findsOneWidget);
  });

  testWidgets('the payment method selector defaults to COD', (tester) async {
    final orderRepository = MockOrderRepository();
    final addressRepository = MockAddressRepository();
    final cartRepository = MockCartRepository();
    when(
      addressRepository.getAddresses(),
    ).thenAnswer((_) async => <AddressResponse>[_address()]);
    when(
      orderRepository.previewCoupon(any),
    ).thenAnswer((_) async => _preview());
    when(cartRepository.getCart()).thenAnswer((_) async => _cart());

    await _pumpCheckout(
      tester,
      orderRepository,
      addressRepository,
      cartRepository,
    );

    final group = tester.widget<RadioGroup<PaymentMethod>>(
      find.byType(RadioGroup<PaymentMethod>),
    );
    expect(group.groupValue, PaymentMethod.cod);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.text('VNPay'), findsOneWidget);
  });

  testWidgets(
    'choosing VNPay places the order with paymentMethod and opens the '
    'payment WebView route',
    (tester) async {
      final orderRepository = MockOrderRepository();
      final addressRepository = MockAddressRepository();
      final cartRepository = MockCartRepository();
      when(
        addressRepository.getAddresses(),
      ).thenAnswer((_) async => <AddressResponse>[_address()]);
      when(
        orderRepository.previewCoupon(any),
      ).thenAnswer((_) async => _preview());
      when(
        orderRepository.placeOrder(any),
      ).thenAnswer((_) async => _order(paymentMethod: PaymentMethod.vnpay));
      when(cartRepository.getCart()).thenAnswer((_) async => _cart());

      await _pumpCheckout(
        tester,
        orderRepository,
        addressRepository,
        cartRepository,
      );

      await tester.tap(find.text('VNPay'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Place Order'));
      await tester.pumpAndSettle();

      final sent =
          verify(orderRepository.placeOrder(captureAny)).captured.single
              as PlaceOrderRequest;
      expect(sent.paymentMethod, PaymentMethod.vnpay);
      expect(find.text('payment-webview-placeholder'), findsOneWidget);
      // The flow never shortcuts to order detail before the WebView reports
      // back — only the payment route is visible so far.
      expect(find.byType(OrderDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'uses SectionHeader for every section title — Items, Shipping address, '
    'Payment method, Coupon, Note, Summary',
    (tester) async {
      final orderRepository = MockOrderRepository();
      final addressRepository = MockAddressRepository();
      final cartRepository = MockCartRepository();
      when(
        addressRepository.getAddresses(),
      ).thenAnswer((_) async => <AddressResponse>[_address()]);
      when(
        orderRepository.previewCoupon(any),
      ).thenAnswer((_) async => _preview());
      when(cartRepository.getCart()).thenAnswer((_) async => _cart());

      await _pumpCheckout(
        tester,
        orderRepository,
        addressRepository,
        cartRepository,
      );

      expect(find.byType(SectionHeader), findsNWidgets(6));
    },
  );

  testWidgets('renders every amount through PriceText — the total is the most '
      'prominent number, no raw money on screen', (tester) async {
    final orderRepository = MockOrderRepository();
    final addressRepository = MockAddressRepository();
    final cartRepository = MockCartRepository();
    when(
      addressRepository.getAddresses(),
    ).thenAnswer((_) async => <AddressResponse>[_address()]);
    when(
      orderRepository.previewCoupon(any),
    ).thenAnswer((_) async => _preview());
    when(cartRepository.getCart()).thenAnswer((_) async => _cart());

    await _pumpCheckout(
      tester,
      orderRepository,
      addressRepository,
      cartRepository,
    );

    // Subtotal + Discount + Shipping + Total = 4 PriceText widgets (no
    // selected cart lines in this fixture).
    expect(find.byType(PriceText), findsNWidgets(4));
    expect(find.text('130.0'), findsNothing);
    expect(find.text('100.0'), findsNothing);

    final totalRow = find.ancestor(
      of: find.text('Total'),
      matching: find.byType(Row),
    );
    final total = tester.widget<PriceText>(
      find.descendant(of: totalRow, matching: find.byType(PriceText)),
    );
    expect(total.variant, PriceVariant.emphasis);
  });

  testWidgets(
    'shows a skeleton while checkout loads — never a centred spinner',
    (tester) async {
      final orderRepository = MockOrderRepository();
      final addressRepository = MockAddressRepository();
      final cartRepository = MockCartRepository();
      final completer = Completer<List<AddressResponse>>();
      when(
        addressRepository.getAddresses(),
      ).thenAnswer((_) => completer.future);
      when(cartRepository.getCart()).thenAnswer((_) async => _cart());

      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ChangeNotifierProvider<CartProvider>.value(
          value: CartProvider(cartRepository),
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: _router(orderRepository, addressRepository),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(ListTileSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(<AddressResponse>[_address()]);
      when(
        orderRepository.previewCoupon(any),
      ).thenAnswer((_) async => _preview());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows AppErrorState on a failed load, with a working retry', (
    tester,
  ) async {
    final orderRepository = MockOrderRepository();
    final addressRepository = MockAddressRepository();
    final cartRepository = MockCartRepository();
    var callCount = 0;
    when(addressRepository.getAddresses()).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const AppException(message: 'Something broke');
      }
      return <AddressResponse>[_address()];
    });
    when(
      orderRepository.previewCoupon(any),
    ).thenAnswer((_) async => _preview());
    when(cartRepository.getCart()).thenAnswer((_) async => _cart());

    await _pumpCheckout(
      tester,
      orderRepository,
      addressRepository,
      cartRepository,
    );

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Something broke'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsNothing);
    expect(find.text('Payment method'), findsOneWidget);
  });

  testWidgets('applying a coupon shows the code, discount via PriceText, and a '
      'Remove action — the Apply control is an OutlinedButton', (tester) async {
    final orderRepository = MockOrderRepository();
    final addressRepository = MockAddressRepository();
    final cartRepository = MockCartRepository();
    when(
      addressRepository.getAddresses(),
    ).thenAnswer((_) async => <AddressResponse>[_address()]);
    when(orderRepository.previewCoupon(any)).thenAnswer((invocation) async {
      final request =
          invocation.positionalArguments.first as CouponPreviewRequest;
      return request.code == null
          ? _preview()
          : _previewWithCoupon(request.code!);
    });
    when(cartRepository.getCart()).thenAnswer((_) async => _cart());

    await _pumpCheckout(
      tester,
      orderRepository,
      addressRepository,
      cartRepository,
    );

    expect(find.widgetWithText(OutlinedButton, 'Apply'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'SAVE10');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Code: SAVE10'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    // Subtotal + Discount + Shipping + Total + the coupon's own discount
    // PriceText.
    expect(find.byType(PriceText), findsNWidgets(5));
  });

  testWidgets(
    'an invalid coupon shows the server message inline with an error icon — '
    'never a SnackBar',
    (tester) async {
      final orderRepository = MockOrderRepository();
      final addressRepository = MockAddressRepository();
      final cartRepository = MockCartRepository();
      when(
        addressRepository.getAddresses(),
      ).thenAnswer((_) async => <AddressResponse>[_address()]);
      when(orderRepository.previewCoupon(any)).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as CouponPreviewRequest;
        if (request.code == null) {
          return _preview();
        }
        throw const AppException(message: 'This coupon code is invalid.');
      });
      when(cartRepository.getCart()).thenAnswer((_) async => _cart());

      await _pumpCheckout(
        tester,
        orderRepository,
        addressRepository,
        cartRepository,
      );

      await tester.enterText(find.byType(TextField).first, 'BAD');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.text('This coupon code is invalid.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('has no bottom navigation on the checkout screen', (
    tester,
  ) async {
    final orderRepository = MockOrderRepository();
    final addressRepository = MockAddressRepository();
    final cartRepository = MockCartRepository();
    when(
      addressRepository.getAddresses(),
    ).thenAnswer((_) async => <AddressResponse>[_address()]);
    when(
      orderRepository.previewCoupon(any),
    ).thenAnswer((_) async => _preview());
    when(cartRepository.getCart()).thenAnswer((_) async => _cart());

    await _pumpCheckout(
      tester,
      orderRepository,
      addressRepository,
      cartRepository,
    );

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}

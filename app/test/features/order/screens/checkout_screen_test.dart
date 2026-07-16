import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/features/address/models/address_response.dart';
import 'package:footverse/features/address/repositories/address_repository.dart';
import 'package:footverse/features/cart/models/cart_response.dart';
import 'package:footverse/features/cart/providers/cart_provider.dart';
import 'package:footverse/features/cart/repositories/cart_repository.dart';
import 'package:footverse/features/order/models/coupon_preview_response.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
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

OrderDetailResponse _order() => OrderDetailResponse(
  id: 700,
  orderCode: 'FV-700',
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

    await tester.pumpWidget(
      ChangeNotifierProvider<CartProvider>.value(
        value: CartProvider(cartRepository),
        child: MaterialApp.router(
          routerConfig: _router(orderRepository, addressRepository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Place Order'));
    await tester.pumpAndSettle();

    verify(orderRepository.placeOrder(any)).called(1);
    // The cart is refreshed through its own public load() → getCart().
    verify(cartRepository.getCart()).called(1);
    // Navigated to the new order's detail.
    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.text('FV-700'), findsOneWidget);
  });
}

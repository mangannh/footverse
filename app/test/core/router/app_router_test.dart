import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/router/app_router.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/core/storage/token_storage.dart';
import 'package:footverse/features/address/models/address_response.dart';
import 'package:footverse/features/address/repositories/address_repository.dart';
import 'package:footverse/features/auth/providers/auth_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/auth/screens/login_screen.dart';
import 'package:footverse/features/cart/providers/cart_provider.dart';
import 'package:footverse/features/cart/repositories/cart_repository.dart';
import 'package:footverse/features/order/models/coupon_preview_response.dart';
import 'package:footverse/features/order/models/order_detail_response.dart';
import 'package:footverse/features/order/models/order_item_response.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/order_summary_response.dart';
import 'package:footverse/features/order/models/payment_method.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:footverse/features/order/screens/checkout_screen.dart';
import 'package:footverse/features/order/screens/order_detail_screen.dart';
import 'package:footverse/features/order/screens/order_list_screen.dart';
import 'package:footverse/features/product/models/product_summary_response.dart';
import 'package:footverse/features/product/repositories/brand_repository.dart';
import 'package:footverse/features/product/repositories/category_repository.dart';
import 'package:footverse/features/product/repositories/product_repository.dart';
import 'package:footverse/features/product/screens/product_list_screen.dart';
import 'package:footverse/features/wishlist/providers/wishlist_provider.dart';
import 'package:footverse/features/wishlist/repositories/wishlist_repository.dart';
import 'package:footverse/shared/models/page_response.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router_test.mocks.dart';

/// One signed-in session and the router driving it, returned so a test can
/// navigate and later flip the auth state.
class _Harness {
  const _Harness(this.router, this.authProvider, this.tokenStorage);

  final GoRouter router;
  final AuthProvider authProvider;
  final TokenStorage tokenStorage;
}

PageResponse<ProductSummaryResponse> _emptyProductPage() =>
    const PageResponse<ProductSummaryResponse>(
      content: <ProductSummaryResponse>[],
      page: 0,
      size: 20,
      totalElements: 0,
      totalPages: 0,
      last: true,
    );

PageResponse<OrderSummaryResponse> _emptyOrderPage() =>
    const PageResponse<OrderSummaryResponse>(
      content: <OrderSummaryResponse>[],
      page: 0,
      size: 20,
      totalElements: 0,
      totalPages: 0,
      last: true,
    );

OrderDetailResponse _orderDetail(int id) => OrderDetailResponse(
  id: id,
  orderCode: 'FV-$id',
  status: OrderStatus.confirmed,
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

/// Builds the real [createAppRouter] behind [MaterialApp.router] with the
/// application-scoped providers, exactly as the composition root wires them. The
/// catalog repositories are stubbed to return empty results so the initial `/`
/// catalog renders without touching a real `Dio`. Auth state is driven through
/// the real [TokenStorage] + [AuthProvider.restoreSession] rather than a fake, so
/// the guard sees the same source the production redirect does.
Future<_Harness> _pumpApp(WidgetTester tester, {required bool signedIn}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final tokenStorage = TokenStorage(await SharedPreferences.getInstance());
  final authProvider = AuthProvider(MockAuthRepository(), tokenStorage);

  final productRepository = MockProductRepository();
  when(
    productRepository.searchProducts(
      name: anyNamed('name'),
      brandId: anyNamed('brandId'),
      categoryId: anyNamed('categoryId'),
      page: anyNamed('page'),
      size: anyNamed('size'),
      sort: anyNamed('sort'),
    ),
  ).thenAnswer((_) async => _emptyProductPage());
  final categoryRepository = MockCategoryRepository();
  when(categoryRepository.getCategories()).thenAnswer((_) async => const []);
  final brandRepository = MockBrandRepository();
  when(brandRepository.getBrands()).thenAnswer((_) async => const []);
  // The checkout screen loads the address book and an initial preview on mount;
  // stub both so navigating to it renders without touching a real Dio.
  final addressRepository = MockAddressRepository();
  when(
    addressRepository.getAddresses(),
  ).thenAnswer((_) async => const <AddressResponse>[]);
  final orderRepository = MockOrderRepository();
  when(orderRepository.previewCoupon(any)).thenAnswer(
    (_) async => const CouponPreviewResponse(
      subtotal: 100,
      discountAmount: 0,
      shippingFee: 30,
      total: 130,
    ),
  );
  // The order-history screen loads the first page on mount; stub it so
  // navigating to it renders without touching a real Dio.
  when(
    orderRepository.getMyOrders(page: anyNamed('page'), size: anyNamed('size')),
  ).thenAnswer((_) async => _emptyOrderPage());
  // The order-detail screen loads the order on mount; echo the requested id into
  // the returned order so a test can assert the right order routed.
  when(orderRepository.getMyOrder(any)).thenAnswer(
    (invocation) async =>
        _orderDetail(invocation.positionalArguments.first as int),
  );

  if (signedIn) {
    await tokenStorage.saveTokens('access', 'refresh');
  }
  authProvider.restoreSession();

  final router = createAppRouter(
    authProvider,
    productRepository,
    categoryRepository,
    brandRepository,
    addressRepository,
    orderRepository,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CartProvider>.value(
          value: CartProvider(MockCartRepository()),
        ),
        ChangeNotifierProvider<WishlistProvider>.value(
          value: WishlistProvider(MockWishlistRepository()),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(router, authProvider, tokenStorage);
}

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<ProductRepository>(),
  MockSpec<CategoryRepository>(),
  MockSpec<BrandRepository>(),
  MockSpec<AddressRepository>(),
  MockSpec<OrderRepository>(),
  MockSpec<CartRepository>(),
  MockSpec<WishlistRepository>(),
])
void main() {
  testWidgets('opens on the public catalog when signed out (no redirect)', (
    tester,
  ) async {
    await _pumpApp(tester, signedIn: false);

    expect(find.byType(ProductListScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('redirects a signed-out user from a guarded route to login', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, signedIn: false);

    harness.router.goNamed(AppRoute.orders);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OrderListScreen), findsNothing);
  });

  testWidgets('returns to the intended route after signing in', (tester) async {
    final harness = await _pumpApp(tester, signedIn: false);

    harness.router.goNamed(AppRoute.checkout, extra: <int>[1, 2]);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Sign in: the guard re-runs on the auth-state change and honours `from`.
    await harness.tokenStorage.saveTokens('access', 'refresh');
    harness.authProvider.restoreSession();
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('a signed-in user reaches the checkout screen', (tester) async {
    final harness = await _pumpApp(tester, signedIn: true);

    harness.router.goNamed(AppRoute.checkout, extra: <int>[1, 2, 3]);
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutScreen), findsOneWidget);
  });

  testWidgets('a signed-in user reaches order history and order detail', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, signedIn: true);

    harness.router.goNamed(AppRoute.orders);
    await tester.pumpAndSettle();
    expect(find.byType(OrderListScreen), findsOneWidget);

    harness.router.goNamed(
      AppRoute.orderDetail,
      pathParameters: <String, String>{'id': '55'},
    );
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.text('FV-55'), findsOneWidget);
  });

  testWidgets(
    'order detail nests under order history for a natural back stack',
    (tester) async {
      final harness = await _pumpApp(tester, signedIn: true);

      harness.router.goNamed(AppRoute.orders);
      await tester.pumpAndSettle();

      harness.router.pushNamed(
        AppRoute.orderDetail,
        pathParameters: <String, String>{'id': '7'},
      );
      await tester.pumpAndSettle();
      expect(find.text('FV-7'), findsOneWidget);

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(OrderListScreen), findsOneWidget);
      expect(find.text('FV-7'), findsNothing);
    },
  );
}

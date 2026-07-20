import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/core/storage/token_storage.dart';
import 'package:footverse/core/widgets/app_empty_state.dart';
import 'package:footverse/core/widgets/app_error_state.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/auth/models/user_response.dart';
import 'package:footverse/features/auth/providers/auth_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/cart/models/cart_item_response.dart';
import 'package:footverse/features/cart/models/cart_response.dart';
import 'package:footverse/features/cart/providers/cart_provider.dart';
import 'package:footverse/features/cart/repositories/cart_repository.dart';
import 'package:footverse/features/product/models/product_detail_response.dart';
import 'package:footverse/features/product/models/product_summary_response.dart';
import 'package:footverse/features/product/models/product_variant_response.dart';
import 'package:footverse/features/product/models/product_variant_status.dart';
import 'package:footverse/features/product/models/review_response.dart';
import 'package:footverse/features/product/repositories/product_repository.dart';
import 'package:footverse/features/product/screens/product_detail_screen.dart';
import 'package:footverse/features/product/widgets/product_card.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:footverse/features/review/repositories/review_repository.dart';
import 'package:footverse/features/wishlist/providers/wishlist_provider.dart';
import 'package:footverse/features/wishlist/repositories/wishlist_repository.dart';
import 'package:footverse/shared/models/page_response.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'product_detail_screen_test.mocks.dart';

// No primaryImageUrl / no images: the gallery placeholder never issues a
// network image request.
ProductDetailResponse _detail({
  List<ProductVariantResponse> variants = const <ProductVariantResponse>[],
  String? description,
}) => ProductDetailResponse(
  id: 1,
  name: 'Air Zoom Pegasus',
  basePrice: 1500000,
  brandId: 5,
  brandName: 'Nike',
  categoryId: 3,
  categoryName: 'Running',
  images: const [],
  variants: variants,
  averageRating: 4.5,
  reviewCount: 2,
  available: true,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
  description: description,
);

const _variants = <ProductVariantResponse>[
  ProductVariantResponse(
    id: 101,
    color: 'Black',
    size: '40',
    price: 1500000,
    stockQuantity: 5,
    status: ProductVariantStatus.active,
    sku: 'SKU-1',
  ),
  ProductVariantResponse(
    id: 102,
    color: 'Black',
    size: '41',
    price: 1500000,
    stockQuantity: 0,
    status: ProductVariantStatus.active,
    sku: 'SKU-2',
  ),
];

ReviewResponse _review(int id) => ReviewResponse(
  id: id,
  productId: 1,
  userId: id,
  userFullName: 'User $id',
  rating: 5,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
  updatedAt: DateTime.parse('2025-01-15T10:30:00'),
);

PageResponse<ReviewResponse> _reviewPage(List<int> ids, {required bool last}) =>
    PageResponse<ReviewResponse>(
      content: ids.map(_review).toList(),
      page: 0,
      size: 20,
      totalElements: ids.length,
      totalPages: 1,
      last: last,
    );

void _stubReviews(
  MockProductRepository repository,
  int page,
  PageResponse<ReviewResponse> result,
) {
  when(
    repository.getProductReviews(
      any,
      page: argThat(equals(page), named: 'page'),
      size: anyNamed('size'),
    ),
  ).thenAnswer((_) async => result);
}

ProductSummaryResponse _relatedProduct(int id) => ProductSummaryResponse(
  id: id,
  name: 'Related Product $id',
  basePrice: 1000000,
  brandName: 'Nike',
  categoryName: 'Running',
  averageRating: 4.0,
  available: true,
);

/// Stubs the related-products fetch `_RelatedProducts` fires on every detail
/// load — every test must stub this, or the widget's own `searchProducts`
/// call throws a `MissingStubError`.
void _stubRelated(
  MockProductRepository repository, {
  List<ProductSummaryResponse> content = const <ProductSummaryResponse>[],
}) {
  when(
    repository.searchProducts(
      name: anyNamed('name'),
      brandId: anyNamed('brandId'),
      categoryId: anyNamed('categoryId'),
      page: anyNamed('page'),
      size: anyNamed('size'),
      sort: anyNamed('sort'),
    ),
  ).thenAnswer(
    (_) async => PageResponse<ProductSummaryResponse>(
      content: content,
      page: 0,
      size: 10,
      totalElements: content.length,
      totalPages: 1,
      last: true,
    ),
  );
}

UserResponse _user(int id) => UserResponse(
  id: id,
  email: 'u$id@example.com',
  fullName: 'User $id',
  phone: '0900000000',
  role: Role.customer,
  enabled: true,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
  updatedAt: DateTime.parse('2025-01-15T10:30:00'),
);

/// Mounts the product detail behind a GoRouter (so the guest write
/// affordance, the not-found empty state, and add-to-cart's guest redirect
/// can all route for real) with the public review list stubbed to
/// [reviewUserIds] as a single last page, related products stubbed to
/// [relatedProducts] (empty by default), and — for a signed-in caller —
/// `GET /users/me` resolving to [meId]. `CartBadge` in the app bar and
/// `AddToCartButton` in the sticky bar both need a live `CartProvider`
/// ancestor, so one is always supplied. A tall surface keeps long slivers
/// built and on-screen so their controls are findable without scrolling.
Future<void> _pumpDetail(
  WidgetTester tester, {
  required bool signedIn,
  int? meId,
  required List<int> reviewUserIds,
  required MockProductRepository productRepository,
  required MockProfileRepository profileRepository,
  MockCartRepository? cartRepository,
  ProductDetailResponse? detail,
  AppException? getProductError,
  List<ProductSummaryResponse> relatedProducts =
      const <ProductSummaryResponse>[],
  bool reviewsLast = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  if (getProductError != null) {
    when(productRepository.getProduct(any)).thenThrow(getProductError);
  } else {
    when(
      productRepository.getProduct(any),
    ).thenAnswer((_) async => detail ?? _detail());
  }
  _stubReviews(
    productRepository,
    0,
    _reviewPage(reviewUserIds, last: reviewsLast),
  );
  _stubRelated(productRepository, content: relatedProducts);
  if (meId != null) {
    when(profileRepository.getMe()).thenAnswer((_) async => _user(meId));
  }

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final tokenStorage = TokenStorage(await SharedPreferences.getInstance());
  if (signedIn) {
    await tokenStorage.saveTokens('access', 'refresh');
  }
  final authProvider = AuthProvider(MockAuthRepository(), tokenStorage);
  authProvider.restoreSession();

  final router = GoRouter(
    initialLocation: '/products/1',
    routes: <RouteBase>[
      GoRoute(
        path: '/products/:id',
        name: AppRoute.productDetail,
        builder: (context, state) => ProductDetailScreen(
          productId: 1,
          productRepository: productRepository,
          reviewRepository: MockReviewRepository(),
          profileRepository: profileRepository,
        ),
      ),
      GoRoute(
        path: '/login',
        name: AppRoute.login,
        builder: (context, state) => const Scaffold(body: Text('LOGIN SCREEN')),
      ),
      GoRoute(
        path: '/catalog',
        name: AppRoute.catalog,
        builder: (context, state) =>
            const Scaffold(body: Text('CATALOG SCREEN')),
      ),
      GoRoute(
        path: '/cart',
        name: AppRoute.cart,
        builder: (context, state) => const Scaffold(body: Text('CART SCREEN')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<WishlistProvider>(
          create: (_) => WishlistProvider(MockWishlistRepository()),
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(cartRepository ?? MockCartRepository()),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([
  MockSpec<ProductRepository>(),
  MockSpec<WishlistRepository>(),
  MockSpec<AuthRepository>(),
  MockSpec<ReviewRepository>(),
  MockSpec<ProfileRepository>(),
  MockSpec<CartRepository>(),
])
void main() {
  testWidgets(
    'auto-loads the next review page when the first page cannot scroll',
    (tester) async {
      final productRepository = MockProductRepository();
      final profileRepository = MockProfileRepository();
      _stubReviews(productRepository, 1, _reviewPage([2], last: true));

      await _pumpDetail(
        tester,
        signedIn: false,
        reviewUserIds: <int>[1],
        productRepository: productRepository,
        profileRepository: profileRepository,
        reviewsLast: false,
      );

      expect(find.text('User 1'), findsOneWidget);
      expect(find.text('User 2'), findsOneWidget);
      verify(
        productRepository.getProductReviews(
          any,
          page: argThat(equals(1), named: 'page'),
          size: anyNamed('size'),
        ),
      ).called(1);
    },
  );

  group('ProductDetailScreen — states (design/04 §4.4)', () {
    testWidgets('shows DetailSkeleton while loading — never a spinner', (
      tester,
    ) async {
      final productRepository = MockProductRepository();
      final completer = Completer<ProductDetailResponse>();
      when(
        productRepository.getProduct(any),
      ).thenAnswer((_) => completer.future);
      _stubReviews(
        productRepository,
        0,
        _reviewPage(const <int>[], last: true),
      );
      _stubRelated(productRepository);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final authProvider = AuthProvider(
        MockAuthRepository(),
        TokenStorage(await SharedPreferences.getInstance()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<WishlistProvider>(
                create: (_) => WishlistProvider(MockWishlistRepository()),
              ),
              ChangeNotifierProvider<CartProvider>(
                create: (_) => CartProvider(MockCartRepository()),
              ),
            ],
            child: ProductDetailScreen(
              productId: 1,
              productRepository: productRepository,
              reviewRepository: MockReviewRepository(),
              profileRepository: MockProfileRepository(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DetailSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(_detail());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a generic load error shows AppErrorState, and retry recovers',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();

        await _pumpDetail(
          tester,
          signedIn: false,
          reviewUserIds: const <int>[],
          productRepository: productRepository,
          profileRepository: profileRepository,
          getProductError: const AppException(message: 'Something broke'),
        );

        expect(find.byType(AppErrorState), findsOneWidget);
        expect(find.text('Something broke'), findsOneWidget);

        when(
          productRepository.getProduct(any),
        ).thenAnswer((_) async => _detail());
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.byType(AppErrorState), findsNothing);
        expect(find.text('Air Zoom Pegasus'), findsWidgets);
      },
    );

    testWidgets(
      'a 404 shows AppEmptyState with "Browse products", routing to the catalog',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();

        await _pumpDetail(
          tester,
          signedIn: false,
          reviewUserIds: const <int>[],
          productRepository: productRepository,
          profileRepository: profileRepository,
          getProductError: const AppException(
            message: 'Product not found',
            statusCode: 404,
          ),
        );

        expect(find.byType(AppEmptyState), findsOneWidget);
        expect(find.text('Browse products'), findsOneWidget);

        await tester.tap(find.text('Browse products'));
        await tester.pumpAndSettle();

        expect(find.text('CATALOG SCREEN'), findsOneWidget);
      },
    );
  });

  group('ProductDetailScreen — Select size (no engineering vocabulary)', () {
    testWidgets(
      'renders "Select size", never "Variants", SKU, Stock, Active or Inactive',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();

        await _pumpDetail(
          tester,
          signedIn: false,
          reviewUserIds: const <int>[],
          productRepository: productRepository,
          profileRepository: profileRepository,
          detail: _detail(variants: _variants),
        );

        expect(find.text('Select size'), findsOneWidget);
        expect(find.text('Variants'), findsNothing);
        expect(find.textContaining('SKU'), findsNothing);
        expect(find.textContaining('Stock'), findsNothing);
        expect(find.text('Active'), findsNothing);
        expect(find.text('Inactive'), findsNothing);
        expect(find.text('40'), findsOneWidget);
        expect(find.text('41'), findsOneWidget);
      },
    );

    testWidgets('an out-of-stock size stays visible but is not selectable', (
      tester,
    ) async {
      final productRepository = MockProductRepository();
      final profileRepository = MockProfileRepository();

      await _pumpDetail(
        tester,
        signedIn: false,
        reviewUserIds: const <int>[],
        productRepository: productRepository,
        profileRepository: profileRepository,
        detail: _detail(variants: _variants),
      );

      // Size 41 (id 102) has stockQuantity: 0 — visible, but tapping it must
      // not select it (the sticky CTA would otherwise flip to "Add to cart").
      await tester.tap(find.text('41'));
      await tester.pumpAndSettle();

      expect(find.text('Select a size'), findsOneWidget);
    });
  });

  group('ProductDetailScreen — sticky Add to Cart CTA (design/04 §4.4)', () {
    testWidgets(
      'shows disabled "Select a size" until a size is chosen, then "Add to cart"',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();

        await _pumpDetail(
          tester,
          signedIn: false,
          reviewUserIds: const <int>[],
          productRepository: productRepository,
          profileRepository: profileRepository,
          detail: _detail(variants: _variants),
        );

        expect(find.text('Select a size'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );

        // Size 40 (id 101) is in stock and active.
        await tester.tap(find.text('40'));
        await tester.pumpAndSettle();

        expect(find.text('Add to cart'), findsOneWidget);
        expect(find.text('Select a size'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'adding to cart shows a snackbar with a working "View cart" action',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();
        final cartRepository = MockCartRepository();
        when(cartRepository.addItem(any)).thenAnswer(
          (_) async => const CartResponse(
            items: <CartItemResponse>[],
            subtotal: 0,
            itemCount: 1,
          ),
        );

        await _pumpDetail(
          tester,
          signedIn: true,
          meId: 1,
          reviewUserIds: const <int>[],
          productRepository: productRepository,
          profileRepository: profileRepository,
          cartRepository: cartRepository,
          detail: _detail(variants: _variants),
        );

        await tester.tap(find.text('40'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add to cart'));
        await tester.pumpAndSettle();

        expect(find.text('Added to cart'), findsOneWidget);
        expect(find.text('View cart'), findsOneWidget);

        await tester.tap(find.text('View cart'));
        await tester.pumpAndSettle();

        expect(find.text('CART SCREEN'), findsOneWidget);
      },
    );
  });

  group('ProductDetailScreen — description (design/04 §4.4)', () {
    testWidgets(
      'a long description collapses with "Show more", expands on tap',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();
        final longDescription = List.filled(
          20,
          'A genuinely long line of description text.',
        ).join(' ');

        await _pumpDetail(
          tester,
          signedIn: false,
          reviewUserIds: const <int>[],
          productRepository: productRepository,
          profileRepository: profileRepository,
          detail: _detail(description: longDescription),
        );

        expect(find.text('Show more'), findsOneWidget);

        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        expect(find.text('Show less'), findsOneWidget);
        expect(find.text('Show more'), findsNothing);
      },
    );
  });

  group('ProductDetailScreen — related products (design/04 §4.4)', () {
    testWidgets(
      'renders related products from the same category, excluding this product',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();

        await _pumpDetail(
          tester,
          signedIn: false,
          reviewUserIds: const <int>[],
          productRepository: productRepository,
          profileRepository: profileRepository,
          // id 1 matches the detail's own id and must be filtered out.
          relatedProducts: <ProductSummaryResponse>[
            _relatedProduct(1),
            _relatedProduct(2),
            _relatedProduct(3),
          ],
        );

        expect(find.text('Related products'), findsOneWidget);
        expect(find.byType(ProductCard), findsNWidgets(2));
        expect(find.text('Related Product 2'), findsOneWidget);
        expect(find.text('Related Product 3'), findsOneWidget);
        expect(find.text('Related Product 1'), findsNothing);
        verify(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: anyNamed('brandId'),
            categoryId: argThat(equals(3), named: 'categoryId'),
            page: anyNamed('page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).called(1);
      },
    );

    testWidgets('omits the section entirely when there is nothing related', (
      tester,
    ) async {
      final productRepository = MockProductRepository();
      final profileRepository = MockProfileRepository();

      await _pumpDetail(
        tester,
        signedIn: false,
        reviewUserIds: const <int>[],
        productRepository: productRepository,
        profileRepository: profileRepository,
      );

      expect(find.text('Related products'), findsNothing);
    });
  });

  group('ProductDetailScreen — reviews (design/03 §26)', () {
    testWidgets('an empty review list shows AppEmptyState, not raw text', (
      tester,
    ) async {
      final productRepository = MockProductRepository();
      final profileRepository = MockProfileRepository();

      await _pumpDetail(
        tester,
        signedIn: false,
        reviewUserIds: const <int>[],
        productRepository: productRepository,
        profileRepository: profileRepository,
      );

      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('No reviews yet.'), findsNothing);
    });
  });

  // The one documented widget-test exception (sprint-9-plan item 08): the review
  // write affordance the product detail shows turns entirely on
  // `review.userId == currentUser.id`, so it is asserted at the screen level.
  group('review write affordance — ownership by userId (item 08)', () {
    testWidgets(
      'the owner (a review.userId matches currentUser.id) sees Edit / Delete, '
      'not Write',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();

        await _pumpDetail(
          tester,
          signedIn: true,
          meId: 7,
          reviewUserIds: <int>[7, 9],
          productRepository: productRepository,
          profileRepository: profileRepository,
        );

        expect(find.text('You reviewed this'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
        expect(find.text('Write a review'), findsNothing);
      },
    );

    testWidgets(
      'a non-owner (no review.userId matches) sees Write, not Edit / Delete',
      (tester) async {
        final productRepository = MockProductRepository();
        final profileRepository = MockProfileRepository();

        await _pumpDetail(
          tester,
          signedIn: true,
          meId: 99,
          reviewUserIds: <int>[7, 9],
          productRepository: productRepository,
          profileRepository: profileRepository,
        );

        expect(find.text('Write a review'), findsOneWidget);
        expect(find.text('You reviewed this'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Edit'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
      },
    );

    testWidgets('a guest sees Write and is routed to login on tap', (
      tester,
    ) async {
      final productRepository = MockProductRepository();
      final profileRepository = MockProfileRepository();

      await _pumpDetail(
        tester,
        signedIn: false,
        reviewUserIds: <int>[7],
        productRepository: productRepository,
        profileRepository: profileRepository,
      );

      // A guest never loads an identity (Design Decision 3) and sees no owner
      // controls; the write affordance routes to login.
      verifyNever(profileRepository.getMe());
      expect(find.text('Write a review'), findsOneWidget);
      expect(find.text('You reviewed this'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Write a review'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN SCREEN'), findsOneWidget);
    });
  });
}

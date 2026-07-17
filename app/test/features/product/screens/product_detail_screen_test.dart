import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/core/storage/token_storage.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/auth/models/user_response.dart';
import 'package:footverse/features/auth/providers/auth_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/product/models/product_detail_response.dart';
import 'package:footverse/features/product/models/review_response.dart';
import 'package:footverse/features/product/repositories/product_repository.dart';
import 'package:footverse/features/product/screens/product_detail_screen.dart';
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

// A minimal detail (no images, no variants) so the header stays short and the
// review list decides whether the page can scroll.
ProductDetailResponse _detail() => ProductDetailResponse(
  id: 1,
  name: 'Air Zoom Pegasus',
  basePrice: 1500000,
  brandId: 5,
  brandName: 'Nike',
  categoryId: 3,
  categoryName: 'Running',
  images: const [],
  variants: const [],
  averageRating: 4.5,
  reviewCount: 2,
  available: true,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
);

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

// Mounts the product detail behind a GoRouter (so the guest write affordance can
// route to a real login route) with the public review list stubbed to
// [reviewUserIds] as a single last page and, for a signed-in caller,
// `GET /users/me` resolving to [meId]. A tall surface keeps the review write
// affordance sliver built and on-screen so its controls are findable without
// scrolling.
Future<void> _pumpDetail(
  WidgetTester tester, {
  required bool signedIn,
  int? meId,
  required List<int> reviewUserIds,
  required MockProductRepository productRepository,
  required MockProfileRepository profileRepository,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  when(productRepository.getProduct(any)).thenAnswer((_) async => _detail());
  _stubReviews(productRepository, 0, _reviewPage(reviewUserIds, last: true));
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
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<WishlistProvider>(
          create: (_) => WishlistProvider(MockWishlistRepository()),
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
])
void main() {
  testWidgets(
    'auto-loads the next review page when the first page cannot scroll',
    (tester) async {
      // A tall viewport so the short first page leaves nothing to scroll,
      // triggering the auto-fill.
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = MockProductRepository();
      when(repository.getProduct(any)).thenAnswer((_) async => _detail());
      _stubReviews(repository, 0, _reviewPage([1], last: false));
      _stubReviews(repository, 1, _reviewPage([2], last: true));

      // The detail app bar embeds the wishlist-owned toggle (reads the
      // application-scoped WishlistProvider) and the review write affordance
      // (reads AuthProvider); supply both, unauthenticated, so the affordances
      // render inert and no identity is loaded (Sprint 9 item 05).
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
            ],
            child: ProductDetailScreen(
              productId: 1,
              productRepository: repository,
              reviewRepository: MockReviewRepository(),
              profileRepository: MockProfileRepository(),
            ),
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(find.text('User 1'), findsOneWidget);
      expect(find.text('User 2'), findsOneWidget);
      verify(
        repository.getProductReviews(
          any,
          page: argThat(equals(1), named: 'page'),
          size: anyNamed('size'),
        ),
      ).called(1);
    },
  );

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

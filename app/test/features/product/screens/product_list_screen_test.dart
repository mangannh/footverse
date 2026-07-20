import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_chips.dart';
import 'package:footverse/core/widgets/app_empty_state.dart';
import 'package:footverse/core/widgets/app_error_state.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';
import 'package:footverse/features/cart/providers/cart_provider.dart';
import 'package:footverse/features/cart/repositories/cart_repository.dart';
import 'package:footverse/features/cart/widgets/cart_badge.dart';
import 'package:footverse/features/product/models/brand_response.dart';
import 'package:footverse/features/product/models/category_response.dart';
import 'package:footverse/features/product/models/product_summary_response.dart';
import 'package:footverse/features/product/repositories/brand_repository.dart';
import 'package:footverse/features/product/repositories/category_repository.dart';
import 'package:footverse/features/product/repositories/product_repository.dart';
import 'package:footverse/features/product/screens/product_list_screen.dart';
import 'package:footverse/features/product/widgets/next_page_footer.dart';
import 'package:footverse/features/product/widgets/product_grid.dart';
import 'package:footverse/shared/models/page_response.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'product_list_screen_test.mocks.dart';

// No primaryImageUrl: the card shows its placeholder, so the test never issues a
// network image request.
ProductSummaryResponse _product(int id) => ProductSummaryResponse(
  id: id,
  name: 'Product $id',
  basePrice: 100,
  brandName: 'Nike',
  categoryName: 'Running',
  averageRating: 4.5,
  available: true,
);

PageResponse<ProductSummaryResponse> _page(
  List<int> ids, {
  required bool last,
}) => PageResponse<ProductSummaryResponse>(
  content: ids.map(_product).toList(),
  page: 0,
  size: 20,
  totalElements: ids.length,
  totalPages: 1,
  last: last,
);

/// Stubs a page by number, matching any search/filter/sort — the same shape
/// the original test used. Fine whenever a test only cares about which
/// *page* comes back, and verifies specific argument values separately with
/// `verify(...)` where it matters.
void _stubPage(
  MockProductRepository repository,
  int page,
  PageResponse<ProductSummaryResponse> result,
) {
  when(
    repository.searchProducts(
      name: anyNamed('name'),
      brandId: anyNamed('brandId'),
      categoryId: anyNamed('categoryId'),
      page: argThat(equals(page), named: 'page'),
      size: anyNamed('size'),
      sort: anyNamed('sort'),
    ),
  ).thenAnswer((_) async => result);
}

/// Stubs the first page keyed by the exact search [name] — used where a test
/// must distinguish "searched for X" from "unfiltered".
void _stubSearchByName(
  MockProductRepository repository,
  String? name,
  PageResponse<ProductSummaryResponse> result,
) {
  when(
    repository.searchProducts(
      name: name == null
          ? argThat(isNull, named: 'name')
          : argThat(equals(name), named: 'name'),
      brandId: anyNamed('brandId'),
      categoryId: anyNamed('categoryId'),
      page: argThat(equals(0), named: 'page'),
      size: anyNamed('size'),
      sort: anyNamed('sort'),
    ),
  ).thenAnswer((_) async => result);
}

@GenerateNiceMocks([
  MockSpec<ProductRepository>(),
  MockSpec<CategoryRepository>(),
  MockSpec<BrandRepository>(),
  MockSpec<CartRepository>(),
])
void main() {
  late MockProductRepository productRepository;
  late MockCategoryRepository categoryRepository;
  late MockBrandRepository brandRepository;
  late MockCartRepository cartRepository;

  setUp(() {
    productRepository = MockProductRepository();
    categoryRepository = MockCategoryRepository();
    brandRepository = MockBrandRepository();
    cartRepository = MockCartRepository();
    when(
      categoryRepository.getCategories(),
    ).thenAnswer((_) async => <CategoryResponse>[]);
    when(
      brandRepository.getBrands(),
    ).thenAnswer((_) async => <BrandResponse>[]);
  });

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(cartRepository),
          child: ProductListScreen(
            productRepository: productRepository,
            categoryRepository: categoryRepository,
            brandRepository: brandRepository,
          ),
        ),
      ),
    );
  }

  group('ProductListScreen — component adoption (design/04 §4.2)', () {
    testWidgets(
      'renders products through ProductGrid, not a single-column ListView',
      (tester) async {
        _stubPage(productRepository, 0, _page([1, 2, 3], last: true));

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        expect(find.byType(ProductGrid), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
      },
    );

    testWidgets(
      'shows a skeleton grid while the first page loads — never a centred spinner',
      (tester) async {
        final completer = Completer<PageResponse<ProductSummaryResponse>>();
        when(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: anyNamed('brandId'),
            categoryId: anyNamed('categoryId'),
            page: anyNamed('page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).thenAnswer((_) => completer.future);

        await pumpScreen(tester);
        await tester.pump();
        await tester.pump();
        await tester.pump(AppMotion.short);
        await tester.pump();

        expect(find.byType(ProductCardSkeleton), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        completer.complete(_page([], last: true));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'shows AppEmptyState with a "Clear filters" action when nothing matches',
      (tester) async {
        _stubPage(productRepository, 0, _page(<int>[], last: true));

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AppEmptyState), findsOneWidget);
        expect(find.text('Clear filters'), findsOneWidget);
        expect(find.text('No products found.'), findsNothing);
      },
    );

    testWidgets(
      'shows AppErrorState on a failed first load, with a working retry',
      (tester) async {
        var callCount = 0;
        when(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: anyNamed('brandId'),
            categoryId: anyNamed('categoryId'),
            page: anyNamed('page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const AppException(message: 'Something broke');
          }
          return _page([1], last: true);
        });

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AppErrorState), findsOneWidget);
        expect(find.text('Something broke'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.byType(AppErrorState), findsNothing);
        expect(find.text('Product 1'), findsOneWidget);
      },
    );

    testWidgets('keeps CartBadge as the cart entry point in the app bar', (
      tester,
    ) async {
      _stubPage(productRepository, 0, _page([1], last: true));

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CartBadge), findsOneWidget);
    });
  });

  group('ProductListScreen — pagination (no regression)', () {
    testWidgets(
      'auto-loads the next page when the first page does not fill the viewport',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // A single-item first page cannot fill an 800 dp viewport at 2
        // columns; the next page must load on its own so the user is never
        // stuck with a partial list.
        _stubPage(productRepository, 0, _page([1], last: false));
        _stubPage(productRepository, 1, _page([2], last: true));

        await pumpScreen(tester);

        // Let loadInitial and the post-frame auto-load both settle.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(find.text('Product 1'), findsOneWidget);
        expect(find.text('Product 2'), findsOneWidget);
        verify(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: anyNamed('brandId'),
            categoryId: anyNamed('categoryId'),
            page: argThat(equals(1), named: 'page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'NextPageFooter shows a retry affordance when loading more fails, and recovers',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        _stubPage(productRepository, 0, _page([1], last: false));
        when(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: anyNamed('brandId'),
            categoryId: anyNamed('categoryId'),
            page: argThat(equals(1), named: 'page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).thenThrow(const AppException(message: 'Could not load more'));

        await pumpScreen(tester);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(find.byType(NextPageFooter), findsOneWidget);
        expect(find.text('Could not load more'), findsOneWidget);

        when(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: anyNamed('brandId'),
            categoryId: anyNamed('categoryId'),
            page: argThat(equals(1), named: 'page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).thenAnswer((_) async => _page([2], last: true));

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Product 2'), findsOneWidget);
      },
    );
  });

  group('ProductListScreen — search (no regression)', () {
    testWidgets('debounced search reloads with the typed text', (tester) async {
      _stubSearchByName(productRepository, null, _page([1], last: true));
      _stubSearchByName(productRepository, 'zoom', _page([2], last: true));

      await pumpScreen(tester);
      await tester.pumpAndSettle();
      expect(find.text('Product 1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zoom');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Product 2'), findsOneWidget);
      expect(find.text('Product 1'), findsNothing);
    });

    testWidgets(
      'tapping Clear filters resets the search text and reloads unfiltered',
      (tester) async {
        _stubSearchByName(productRepository, null, _page([1], last: true));
        _stubSearchByName(
          productRepository,
          'zoom',
          _page(<int>[], last: true),
        );

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'zoom');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.byType(AppEmptyState), findsOneWidget);

        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();

        expect(find.text('Product 1'), findsOneWidget);
        expect(find.byType(AppEmptyState), findsNothing);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text ?? '', isEmpty);
      },
    );
  });

  group('ProductListScreen — filter & sort (no regression)', () {
    testWidgets(
      'applying a brand filter via the sheet shows an ActiveFilterChip and reloads filtered results',
      (tester) async {
        when(
          brandRepository.getBrands(),
        ).thenAnswer((_) async => const [BrandResponse(id: 1, name: 'Nike')]);
        _stubPage(productRepository, 0, _page([1, 2], last: true));

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Filter and sort'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilterChip, 'Nike'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ActiveFilterChip),
            matching: find.text('Nike'),
          ),
          findsOneWidget,
        );
        verify(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: argThat(equals(1), named: 'brandId'),
            categoryId: anyNamed('categoryId'),
            page: anyNamed('page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'removing an active filter chip clears it and reloads unfiltered',
      (tester) async {
        when(
          brandRepository.getBrands(),
        ).thenAnswer((_) async => const [BrandResponse(id: 1, name: 'Nike')]);
        _stubPage(productRepository, 0, _page([1, 2], last: true));

        await pumpScreen(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Filter and sort'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Nike'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.byType(ActiveFilterChip), findsOneWidget);

        await tester.tap(find.byTooltip('Remove Nike filter'));
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsNothing);
        verify(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: argThat(isNull, named: 'brandId'),
            categoryId: anyNamed('categoryId'),
            page: anyNamed('page'),
            size: anyNamed('size'),
            sort: anyNamed('sort'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'applying a sort via the sheet shows a sort ActiveFilterChip and reloads sorted results',
      (tester) async {
        _stubPage(productRepository, 0, _page([1], last: true));

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Filter and sort'));
        await tester.pumpAndSettle();

        // "Price" sits in the sort section, below brand/category — scroll it
        // into view first (the sheet's selection groups live inside a
        // `SingleChildScrollView`).
        await tester.ensureVisible(find.widgetWithText(FilterChip, 'Price'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Price'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(ActiveFilterChip),
            matching: find.text('Price'),
          ),
          findsOneWidget,
        );
        verify(
          productRepository.searchProducts(
            name: anyNamed('name'),
            brandId: anyNamed('brandId'),
            categoryId: anyNamed('categoryId'),
            page: anyNamed('page'),
            size: anyNamed('size'),
            sort: argThat(equals(ProductSort.basePrice), named: 'sort'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );
  });
}

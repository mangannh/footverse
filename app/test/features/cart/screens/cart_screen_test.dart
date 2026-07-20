import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_empty_state.dart';
import 'package:footverse/core/widgets/app_error_state.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';
import 'package:footverse/core/widgets/price_text.dart';
import 'package:footverse/core/widgets/quantity_selector.dart';
import 'package:footverse/features/cart/models/cart_item_response.dart';
import 'package:footverse/features/cart/models/cart_response.dart';
import 'package:footverse/features/cart/providers/cart_provider.dart';
import 'package:footverse/features/cart/repositories/cart_repository.dart';
import 'package:footverse/features/cart/screens/cart_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'cart_screen_test.mocks.dart';

CartItemResponse _item(int id, {required bool available, int quantity = 1}) =>
    CartItemResponse(
      id: id,
      productVariantId: id * 10,
      productId: id * 100,
      productName: 'Product $id',
      productImageUrl: null,
      color: 'Black',
      size: '42',
      unitPrice: 100,
      quantity: quantity,
      lineTotal: 100.0 * quantity,
      available: available,
    );

// Two available lines (1, 2) and one unavailable line (3).
CartResponse _cart() => CartResponse(
  items: <CartItemResponse>[
    _item(1, available: true),
    _item(2, available: true),
    _item(3, available: false),
  ],
  subtotal: 300,
  itemCount: 3,
);

/// A stand-in for the checkout route: it renders the `cartItemIds` it received via
/// the typed `extra`, so a test can assert exactly which ids were passed.
class _CheckoutProbe extends StatelessWidget {
  const _CheckoutProbe({required this.ids});

  final List<int> ids;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('ids:${ids.join(',')}')));
}

/// A stand-in for the catalog route, so a test can assert the empty state's
/// "Browse products" action actually navigates there.
class _CatalogProbe extends StatelessWidget {
  const _CatalogProbe();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('catalog')));
}

GoRouter _router() => GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const CartScreen()),
    GoRoute(
      path: '/checkout',
      name: AppRoute.checkout,
      builder: (context, state) =>
          _CheckoutProbe(ids: (state.extra as List<int>?) ?? const <int>[]),
    ),
    GoRoute(
      path: '/catalog',
      name: AppRoute.catalog,
      builder: (context, state) => const _CatalogProbe(),
    ),
  ],
);

FilledButton _checkoutButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Checkout'));

List<Checkbox> _checkboxes(WidgetTester tester) =>
    tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();

Future<void> _pumpCart(
  WidgetTester tester,
  MockCartRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ChangeNotifierProvider<CartProvider>.value(
      value: CartProvider(repository),
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<CartRepository>()])
void main() {
  late MockCartRepository repository;

  setUp(() {
    repository = MockCartRepository();
    when(repository.getCart()).thenAnswer((_) async => _cart());
  });

  testWidgets(
    'selects every available line by default, not the unavailable one',
    (tester) async {
      await _pumpCart(tester, repository);

      final checkboxes = _checkboxes(tester);
      expect(checkboxes, hasLength(3));
      expect(checkboxes[0].value, isTrue);
      expect(checkboxes[1].value, isTrue);
      expect(checkboxes[2].value, isFalse);
      expect(find.text('2 selected'), findsOneWidget);
    },
  );

  testWidgets('renders the unavailable line as flagged and not selectable', (
    tester,
  ) async {
    await _pumpCart(tester, repository);

    // Icon-and-text flag plus a disabled checkbox — not colour alone.
    expect(find.text('Unavailable'), findsOneWidget);
    expect(_checkboxes(tester)[2].onChanged, isNull);
    expect(_checkboxes(tester)[0].onChanged, isNotNull);
  });

  testWidgets('enables checkout with a selection and disables it with none', (
    tester,
  ) async {
    await _pumpCart(tester, repository);

    expect(_checkoutButton(tester).onPressed, isNotNull);

    // Deselect both available lines.
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    expect(find.text('0 selected'), findsOneWidget);
    expect(_checkoutButton(tester).onPressed, isNull);
  });

  testWidgets('passes exactly the selected ids to the checkout route', (
    tester,
  ) async {
    await _pumpCart(tester, repository);

    // Deselect the first available line (id 1); id 2 remains selected.
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('ids:2'), findsOneWidget);
  });

  testWidgets('quantity update and removal still round-trip (no regression)', (
    tester,
  ) async {
    when(repository.updateItem(any, any)).thenAnswer((_) async => _cart());
    when(repository.removeItem(any)).thenAnswer((_) async => _cart());
    await _pumpCart(tester, repository);

    await tester.tap(find.byTooltip('Increase quantity').first);
    await tester.pumpAndSettle();
    verify(repository.updateItem(argThat(equals(1)), any)).called(1);

    await tester.tap(find.widgetWithText(TextButton, 'Remove').first);
    await tester.pumpAndSettle();
    verify(repository.removeItem(1)).called(1);
  });

  testWidgets('uses the shared QuantitySelector, not a private stepper', (
    tester,
  ) async {
    await _pumpCart(tester, repository);

    expect(find.byType(QuantitySelector), findsNWidgets(3));
  });

  testWidgets(
    'renders every amount through PriceText — no raw money on screen',
    (tester) async {
      await _pumpCart(tester, repository);

      // unitPrice + lineTotal per of the 3 lines, plus the subtotal.
      expect(find.byType(PriceText), findsNWidgets(7));
      expect(find.text('300.0'), findsNothing);
      expect(find.text('100.0'), findsNothing);
    },
  );

  testWidgets(
    'shows a skeleton while the cart loads — never a centred spinner',
    (tester) async {
      final completer = Completer<CartResponse>();
      when(repository.getCart()).thenAnswer((_) => completer.future);

      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<CartProvider>.value(
          value: CartProvider(repository),
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: _router(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(ListTileSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(_cart());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'shows AppEmptyState with a "Browse products" action for an empty cart',
    (tester) async {
      when(repository.getCart()).thenAnswer(
        (_) async => const CartResponse(items: [], subtotal: 0, itemCount: 0),
      );

      await _pumpCart(tester, repository);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse products'), findsOneWidget);

      await tester.tap(find.text('Browse products'));
      await tester.pumpAndSettle();

      expect(find.text('catalog'), findsOneWidget);
    },
  );

  testWidgets('shows AppErrorState on a failed load, with a working retry', (
    tester,
  ) async {
    var callCount = 0;
    when(repository.getCart()).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const AppException(message: 'Something broke');
      }
      return _cart();
    });

    await _pumpCart(tester, repository);

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Something broke'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsNothing);
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('has a RefreshIndicator that reloads the cart', (tester) async {
    await _pumpCart(tester, repository);

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    verify(repository.getCart()).called(greaterThanOrEqualTo(2));
  });
}

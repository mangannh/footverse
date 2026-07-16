import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/router/app_routes.dart';
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

GoRouter _router() => GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const CartScreen()),
    GoRoute(
      path: '/checkout',
      name: AppRoute.checkout,
      builder: (context, state) =>
          _CheckoutProbe(ids: (state.extra as List<int>?) ?? const <int>[]),
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
      child: MaterialApp.router(routerConfig: _router()),
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
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/storage/token_storage.dart';
import 'package:footverse/core/widgets/app_buttons.dart';
import 'package:footverse/features/auth/providers/auth_provider.dart';
import 'package:footverse/features/auth/repositories/auth_repository.dart';
import 'package:footverse/features/cart/models/cart_item_response.dart';
import 'package:footverse/features/cart/models/cart_response.dart';
import 'package:footverse/features/cart/providers/cart_provider.dart';
import 'package:footverse/features/cart/repositories/cart_repository.dart';
import 'package:footverse/features/cart/widgets/add_to_cart_button.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_to_cart_button_test.mocks.dart';

const _cart = CartResponse(
  items: <CartItemResponse>[],
  subtotal: 0,
  itemCount: 1,
);

/// Mounts [AddToCartButton] behind a GoRouter (for the guest → login redirect
/// and, when [onAdded] pushes it, the `cart` route) with a real
/// [AuthProvider]/[CartProvider] pair.
Future<void> _pump(
  WidgetTester tester, {
  required int? productVariantId,
  required bool purchasable,
  required bool signedIn,
  MockCartRepository? cartRepository,
  VoidCallback? onAdded,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final tokenStorage = TokenStorage(await SharedPreferences.getInstance());
  if (signedIn) {
    await tokenStorage.saveTokens('access', 'refresh');
  }
  final authProvider = AuthProvider(MockAuthRepository(), tokenStorage);
  authProvider.restoreSession();

  final router = GoRouter(
    initialLocation: '/product',
    routes: <RouteBase>[
      GoRoute(
        path: '/product',
        name: 'productDetail',
        builder: (context, state) => Scaffold(
          body: AddToCartButton(
            productVariantId: productVariantId,
            purchasable: purchasable,
            onAdded: onAdded,
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const Scaffold(body: Text('LOGIN SCREEN')),
      ),
      GoRoute(
        path: '/cart',
        name: 'cart',
        builder: (context, state) => const Scaffold(body: Text('CART SCREEN')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(cartRepository ?? MockCartRepository()),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<CartRepository>(), MockSpec<AuthRepository>()])
void main() {
  group('AddToCartButton — label states (design/04 §4.4)', () {
    testWidgets('no size selected shows "Select a size", disabled', (
      tester,
    ) async {
      await _pump(
        tester,
        productVariantId: null,
        purchasable: false,
        signedIn: true,
      );

      expect(find.text('Select a size'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets(
      'a selected but unpurchasable variant shows "Out of stock", disabled',
      (tester) async {
        await _pump(
          tester,
          productVariantId: 1,
          purchasable: false,
          signedIn: true,
        );

        expect(find.text('Out of stock'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'a selected, purchasable variant shows "Add to cart", enabled',
      (tester) async {
        await _pump(
          tester,
          productVariantId: 1,
          purchasable: true,
          signedIn: true,
        );

        expect(find.text('Add to cart'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      },
    );
  });

  group('AddToCartButton — reuses AppPrimaryButton (design/03 §1)', () {
    testWidgets(
      'renders through AppPrimaryButton — width unchanged, in-button spinner',
      (tester) async {
        final cartRepository = MockCartRepository();
        final completer = Completer<CartResponse>();
        when(cartRepository.addItem(any)).thenAnswer((_) => completer.future);

        await _pump(
          tester,
          productVariantId: 1,
          purchasable: true,
          signedIn: true,
          cartRepository: cartRepository,
        );

        expect(find.byType(AppPrimaryButton), findsOneWidget);
        final idleWidth = tester.getSize(find.byType(AppPrimaryButton)).width;

        await tester.tap(find.text('Add to cart'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.getSize(find.byType(AppPrimaryButton)).width, idleWidth);

        completer.complete(_cart);
        await tester.pumpAndSettle();
      },
    );
  });

  group(
    'AddToCartButton — guest redirect (business-rules → Guest capabilities)',
    () {
      testWidgets('a guest tap routes to login instead of calling addItem', (
        tester,
      ) async {
        final cartRepository = MockCartRepository();

        await _pump(
          tester,
          productVariantId: 1,
          purchasable: true,
          signedIn: false,
          cartRepository: cartRepository,
        );

        await tester.tap(find.text('Add to cart'));
        await tester.pumpAndSettle();

        expect(find.text('LOGIN SCREEN'), findsOneWidget);
        verifyNever(cartRepository.addItem(any));
      });
    },
  );

  group('AddToCartButton — onAdded callback (backward compatible)', () {
    testWidgets(
      'onAdded is called instead of the default snackbar when supplied',
      (tester) async {
        final cartRepository = MockCartRepository();
        when(cartRepository.addItem(any)).thenAnswer((_) async => _cart);
        var addedCalled = false;

        await _pump(
          tester,
          productVariantId: 1,
          purchasable: true,
          signedIn: true,
          cartRepository: cartRepository,
          onAdded: () => addedCalled = true,
        );

        await tester.tap(find.text('Add to cart'));
        await tester.pumpAndSettle();

        expect(addedCalled, isTrue);
        expect(find.text('Added to cart'), findsNothing);
      },
    );

    testWidgets(
      'without onAdded, the default "Added to cart" snackbar still shows — unchanged for every existing call site',
      (tester) async {
        final cartRepository = MockCartRepository();
        when(cartRepository.addItem(any)).thenAnswer((_) async => _cart);

        await _pump(
          tester,
          productVariantId: 1,
          purchasable: true,
          signedIn: true,
          cartRepository: cartRepository,
        );

        await tester.tap(find.text('Add to cart'));
        await tester.pumpAndSettle();

        expect(find.text('Added to cart'), findsOneWidget);
      },
    );
  });
}

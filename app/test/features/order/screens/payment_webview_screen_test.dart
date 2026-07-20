import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_error_state.dart';
import 'package:footverse/features/order/models/payment_url_response.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:footverse/features/order/screens/payment_webview_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'payment_webview_screen_test.mocks.dart';

/// Every test here keeps `createPaymentUrl` from ever succeeding, so the
/// screen never constructs a real `WebViewController` — `webview_flutter`
/// has no platform implementation registered in a plain widget test, and the
/// navigation/return-detection logic is unchanged by this sprint's restyle,
/// so it is not what these tests exist to cover.
GoRouter _router(OrderRepository repository) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const Scaffold(body: Text('previous-screen')),
      routes: <RouteBase>[
        GoRoute(
          path: 'payment',
          builder: (context, state) =>
              PaymentWebViewScreen(orderId: 700, orderRepository: repository),
        ),
      ],
    ),
  ],
);

Future<void> _pumpScreen(
  WidgetTester tester,
  MockOrderRepository repository,
) async {
  final router = _router(repository);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  router.push('/payment');
  await tester.pumpAndSettle();
  // The screen's `create:` fires `requestPaymentUrl()` fire-and-forget
  // (PaymentProvider rethrows so an explicit `onRetry` caller — e.g.
  // AppErrorState's own retry — can catch it); with no such caller for this
  // very first call, a stubbed failure surfaces as an otherwise-unhandled
  // Future error the test framework would fail on. It is already fully
  // handled by the provider's own try/catch (status → error, message
  // preserved) before it reaches here, so it is safe to discard.
  tester.takeException();
}

@GenerateNiceMocks([MockSpec<OrderRepository>()])
void main() {
  late MockOrderRepository repository;

  setUp(() {
    repository = MockOrderRepository();
  });

  testWidgets(
    'shows a spinner while requesting the payment URL — the one permitted '
    'full-screen exception for this screen',
    (tester) async {
      final completer = Completer<PaymentUrlResponse>();
      when(
        repository.createPaymentUrl(any),
      ).thenAnswer((_) => completer.future);

      final router = _router(repository);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      router.push('/payment');
      // An indeterminate CircularProgressIndicator animates forever, so this
      // state cannot use pumpAndSettle — a few explicit pumps are enough to
      // reach it.
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppErrorState), findsNothing);

      completer.complete(
        PaymentUrlResponse(
          paymentUrl: 'https://sandbox.vnpayment.vn/pay',
          txnRef: 'TXN1',
          expiresAt: DateTime(2026, 7, 20),
        ),
      );
      // Do not settle further — a successful resolution would construct a
      // real WebViewController, which has no platform implementation here.
    },
  );

  testWidgets(
    'shows AppErrorState when the payment URL request fails, and retry '
    're-invokes it',
    (tester) async {
      when(repository.createPaymentUrl(any)).thenAnswer(
        (_) async => throw const AppException(message: 'Cannot pay right now'),
      );

      await _pumpScreen(tester, repository);

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.text('Cannot pay right now'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      verify(repository.createPaymentUrl(700)).called(2);
      expect(find.byType(AppErrorState), findsOneWidget);
    },
  );

  testWidgets(
    'Cancel requires confirmation — "Keep paying" leaves the screen open',
    (tester) async {
      when(
        repository.createPaymentUrl(any),
      ).thenAnswer((_) async => throw const AppException(message: 'broke'));

      await _pumpScreen(tester, repository);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel payment?'), findsOneWidget);

      await tester.tap(find.text('Keep paying'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel payment?'), findsNothing);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('previous-screen'), findsNothing);
    },
  );

  testWidgets(
    'confirming Cancel payment pops back without rendering any payment '
    'outcome',
    (tester) async {
      when(
        repository.createPaymentUrl(any),
      ).thenAnswer((_) async => throw const AppException(message: 'broke'));

      await _pumpScreen(tester, repository);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel payment'));
      await tester.pumpAndSettle();

      expect(find.text('previous-screen'), findsOneWidget);
      // The order's own repository was never asked to reload — cancelling
      // before the gateway ever loaded renders no payment status at all.
      verifyNever(repository.getMyOrder(any));
    },
  );

  testWidgets('has no bottom navigation and no pull-to-refresh', (
    tester,
  ) async {
    when(
      repository.createPaymentUrl(any),
    ).thenAnswer((_) async => throw const AppException(message: 'broke'));

    await _pumpScreen(tester, repository);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
  });
}

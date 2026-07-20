import 'dart:async' show Completer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/core/router/app_routes.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_empty_state.dart';
import 'package:footverse/core/widgets/app_error_state.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/order_summary_response.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:footverse/features/order/screens/order_list_screen.dart';
import 'package:footverse/features/order/widgets/order_card.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:footverse/shared/models/page_response.dart';

import 'order_list_screen_test.mocks.dart';

OrderSummaryResponse _order(int id) => OrderSummaryResponse(
  id: id,
  orderCode: 'FV-$id',
  status: OrderStatus.pending,
  paymentStatus: PaymentStatus.unpaid,
  total: 130,
  itemCount: 2,
  createdAt: DateTime(2026, 7, 19),
);

PageResponse<OrderSummaryResponse> _page(List<int> ids, {required bool last}) =>
    PageResponse<OrderSummaryResponse>(
      content: ids.map(_order).toList(),
      page: 0,
      size: 20,
      totalElements: ids.length,
      totalPages: 1,
      last: last,
    );

GoRouter _router(OrderRepository repository) => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => OrderListScreen(orderRepository: repository),
      routes: <RouteBase>[
        GoRoute(
          path: 'orders/:id',
          name: AppRoute.orderDetail,
          builder: (context, state) => Scaffold(
            body: Text('order-detail:${state.pathParameters['id']}'),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/catalog',
      name: AppRoute.catalog,
      builder: (context, state) => const Scaffold(body: Text('catalog')),
    ),
  ],
);

Future<void> _pumpScreen(
  WidgetTester tester,
  MockOrderRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _router(repository),
    ),
  );
  await tester.pumpAndSettle();
}

@GenerateNiceMocks([MockSpec<OrderRepository>()])
void main() {
  late MockOrderRepository repository;

  setUp(() {
    repository = MockOrderRepository();
  });

  testWidgets('renders one OrderCard per order and navigates to its detail', (
    tester,
  ) async {
    when(
      repository.getMyOrders(page: anyNamed('page'), size: anyNamed('size')),
    ).thenAnswer((_) async => _page(<int>[1, 2], last: true));

    await _pumpScreen(tester, repository);

    expect(find.byType(OrderCard), findsNWidgets(2));

    await tester.tap(find.text('FV-1'));
    await tester.pumpAndSettle();

    expect(find.text('order-detail:1'), findsOneWidget);
  });

  testWidgets(
    'shows a skeleton while the first page loads — never a centred spinner',
    (tester) async {
      final completer = Completer<PageResponse<OrderSummaryResponse>>();
      when(
        repository.getMyOrders(page: anyNamed('page'), size: anyNamed('size')),
      ).thenAnswer((_) => completer.future);

      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: _router(repository),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(ListTileSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(_page(<int>[], last: true));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'shows AppEmptyState with a "Start shopping" action for no orders',
    (tester) async {
      when(
        repository.getMyOrders(page: anyNamed('page'), size: anyNamed('size')),
      ).thenAnswer((_) async => _page(<int>[], last: true));

      await _pumpScreen(tester, repository);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Start shopping'), findsOneWidget);

      await tester.tap(find.text('Start shopping'));
      await tester.pumpAndSettle();

      expect(find.text('catalog'), findsOneWidget);
    },
  );

  testWidgets('shows AppErrorState on a failed load, with a working retry', (
    tester,
  ) async {
    var callCount = 0;
    when(
      repository.getMyOrders(page: anyNamed('page'), size: anyNamed('size')),
    ).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const AppException(message: 'Something broke');
      }
      return _page(<int>[1], last: true);
    });

    await _pumpScreen(tester, repository);

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Something broke'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsNothing);
    expect(find.byType(OrderCard), findsOneWidget);
  });

  testWidgets('has a RefreshIndicator that reloads the list', (tester) async {
    when(
      repository.getMyOrders(page: anyNamed('page'), size: anyNamed('size')),
    ).thenAnswer((_) async => _page(<int>[1], last: true));

    await _pumpScreen(tester, repository);

    expect(find.byType(RefreshIndicator), findsOneWidget);

    final refreshState = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    unawaited(refreshState.show());
    await tester.pumpAndSettle();

    verify(
      repository.getMyOrders(page: anyNamed('page'), size: anyNamed('size')),
    ).called(greaterThanOrEqualTo(2));
  });
}

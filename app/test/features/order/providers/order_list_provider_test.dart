import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/order_summary_response.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/providers/order_list_provider.dart';
import 'package:footverse/features/order/repositories/order_repository.dart';
import 'package:footverse/shared/models/page_response.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'order_list_provider_test.mocks.dart';

OrderSummaryResponse _order(int id) => OrderSummaryResponse(
  id: id,
  orderCode: 'FV-$id',
  status: OrderStatus.pending,
  paymentStatus: PaymentStatus.unpaid,
  total: 130,
  itemCount: 2,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
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

/// Stubs `getMyOrders` for a specific `page` value, matching `size` loosely.
void _stubPage(
  MockOrderRepository repository,
  int page,
  Future<PageResponse<OrderSummaryResponse>> Function() answer,
) {
  when(
    repository.getMyOrders(
      page: argThat(equals(page), named: 'page'),
      size: anyNamed('size'),
    ),
  ).thenAnswer((_) => answer());
}

@GenerateNiceMocks([MockSpec<OrderRepository>()])
void main() {
  late MockOrderRepository orderRepository;
  late OrderListProvider provider;

  setUp(() {
    orderRepository = MockOrderRepository();
    provider = OrderListProvider(orderRepository);
  });

  group('load', () {
    test(
      'loads the first page newest-first as the server returns it',
      () async {
        _stubPage(
          orderRepository,
          0,
          () async => _page([3, 2, 1], last: false),
        );

        await provider.load();

        expect(provider.status, OrderListStatus.ready);
        expect(provider.orders.map((o) => o.id), <int>[3, 2, 1]);
        expect(provider.isEmpty, isFalse);
        verify(
          orderRepository.getMyOrders(page: 0, size: anyNamed('size')),
        ).called(1);
      },
    );

    test('exposes the empty state when the caller has no orders', () async {
      _stubPage(orderRepository, 0, () async => _page([], last: true));

      await provider.load();

      expect(provider.status, OrderListStatus.ready);
      expect(provider.orders, isEmpty);
      expect(provider.isEmpty, isTrue);
    });

    test('exposes the error state when the first page fails', () async {
      _stubPage(
        orderRepository,
        0,
        () async => throw const AppException(message: 'boom'),
      );

      await provider.load();

      expect(provider.status, OrderListStatus.error);
      expect(provider.orders, isEmpty);
      expect(provider.error?.message, 'boom');
    });

    test('retry reloads the first page after an error', () async {
      _stubPage(
        orderRepository,
        0,
        () async => throw const AppException(message: 'boom'),
      );

      await provider.load();
      expect(provider.status, OrderListStatus.error);

      _stubPage(orderRepository, 0, () async => _page([2, 1], last: true));
      await provider.retry();

      expect(provider.status, OrderListStatus.ready);
      expect(provider.orders.map((o) => o.id), <int>[2, 1]);
      expect(provider.error, isNull);
    });
  });

  group('infinite scrolling', () {
    test('appends the next page and advances the page cursor', () async {
      _stubPage(orderRepository, 0, () async => _page([4, 3], last: false));
      _stubPage(orderRepository, 1, () async => _page([2, 1], last: true));

      await provider.load();
      await provider.loadNextPage();

      expect(provider.orders.map((o) => o.id), <int>[4, 3, 2, 1]);
      verify(
        orderRepository.getMyOrders(page: 1, size: anyNamed('size')),
      ).called(1);
    });

    test('does not issue a duplicate request while one is in flight', () async {
      _stubPage(orderRepository, 0, () async => _page([2], last: false));
      final gate = Completer<PageResponse<OrderSummaryResponse>>();
      _stubPage(orderRepository, 1, () => gate.future);

      await provider.load();
      final first = provider.loadNextPage();
      final second = provider.loadNextPage();

      expect(provider.loadingNextPage, isTrue);
      gate.complete(_page([1], last: true));
      await Future.wait(<Future<void>>[first, second]);

      verify(
        orderRepository.getMyOrders(page: 1, size: anyNamed('size')),
      ).called(1);
    });

    test('stops requesting once the last page is reached', () async {
      _stubPage(orderRepository, 0, () async => _page([1], last: true));

      await provider.load();
      await provider.loadNextPage();

      verifyNever(orderRepository.getMyOrders(page: 1, size: anyNamed('size')));
    });

    test('a next-page error preserves the existing orders', () async {
      _stubPage(orderRepository, 0, () async => _page([2, 1], last: false));
      _stubPage(
        orderRepository,
        1,
        () async => throw const AppException(message: 'page failed'),
      );

      await provider.load();
      await provider.loadNextPage();

      expect(provider.status, OrderListStatus.ready);
      expect(provider.orders.map((o) => o.id), <int>[2, 1]);
      expect(provider.loadingNextPage, isFalse);
      expect(provider.nextPageError?.message, 'page failed');
    });

    test('discards a stale next-page response after a retry', () async {
      _stubPage(orderRepository, 0, () async => _page([2, 1], last: false));
      final gate = Completer<PageResponse<OrderSummaryResponse>>();
      _stubPage(orderRepository, 1, () => gate.future);

      await provider.load();
      final pending = provider.loadNextPage(); // page 1 hangs in flight

      // A retry reloads the list from page 0 with different content.
      _stubPage(orderRepository, 0, () async => _page([9], last: true));
      await provider.retry();

      // The stale page-1 response now arrives and must be ignored.
      gate.complete(_page([3], last: false));
      await pending;

      expect(provider.orders.map((o) => o.id), <int>[9]);
      expect(provider.status, OrderListStatus.ready);
      expect(provider.loadingNextPage, isFalse);
    });
  });

  group('lifecycle', () {
    test('a load that completes after dispose does not throw', () async {
      final gate = Completer<PageResponse<OrderSummaryResponse>>();
      _stubPage(orderRepository, 0, () => gate.future);

      final pending = provider.load();
      provider.dispose();
      gate.complete(_page([1], last: true));

      // No notifyListeners fires after dispose, so this completes normally.
      await expectLater(pending, completes);
    });
  });
}

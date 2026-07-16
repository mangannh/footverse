import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../product/widgets/next_page_footer.dart';
import '../providers/order_list_provider.dart';
import '../repositories/order_repository.dart';
import '../widgets/order_summary_tile.dart';

/// The caller's order history (sprint-8-plan item 06): a paginated,
/// most-recently-placed-first list. It owns a screen-scoped [OrderListProvider]
/// built from the injected [OrderRepository] and loads the first page on mount;
/// the repository arrives from the composition root so no widget constructs a
/// `Dio` (flutter-guidelines §Networking). Reached from the account-screen
/// "My Orders" entry; each row opens the order detail through the existing route.
class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key, required this.orderRepository});

  final OrderRepository orderRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrderListProvider>(
      create: (_) => OrderListProvider(orderRepository)..load(),
      child: const _OrderListView(),
    );
  }
}

/// Renders the order list and drives infinite scrolling: it loads the next page
/// when the scroll position nears the bottom (the provider guards against
/// duplicate and surplus requests). Mirrors the Sprint 6 catalog list idiom.
class _OrderListView extends StatefulWidget {
  const _OrderListView();

  @override
  State<_OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends State<_OrderListView> {
  final ScrollController _scrollController = ScrollController();

  static const double _loadMoreThreshold = 200;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      context.read<OrderListProvider>().loadNextPage();
    }
  }

  /// Loads the next page when the current list is too short to scroll: a page
  /// smaller than the viewport would otherwise never fire [_onScroll]. Runs after
  /// layout so the scroll extent is known; the provider stops once the last page
  /// is reached.
  void _autoLoadIfNotScrollable() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.maxScrollExtent == 0) {
      context.read<OrderListProvider>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderListProvider>();
    if (provider.status == OrderListStatus.ready && !provider.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoLoadIfNotScrollable(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: SafeArea(child: _buildBody(context, provider)),
    );
  }

  Widget _buildBody(BuildContext context, OrderListProvider provider) {
    switch (provider.status) {
      case OrderListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case OrderListStatus.error:
        return _ErrorView(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: context.read<OrderListProvider>().retry,
        );
      case OrderListStatus.ready:
        if (provider.isEmpty) {
          return const _EmptyView();
        }
        return _buildList(context, provider);
    }
  }

  Widget _buildList(BuildContext context, OrderListProvider provider) {
    final orders = provider.orders;
    final hasFooter =
        provider.loadingNextPage || provider.nextPageError != null;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      itemCount: orders.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= orders.length) {
          return NextPageFooter(
            loading: provider.loadingNextPage,
            error: provider.nextPageError?.message,
            onRetry: context.read<OrderListProvider>().loadNextPage,
          );
        }
        final order = orders[index];
        return OrderSummaryTile(
          order: order,
          onTap: () => context.goNamed(
            AppRoute.orderDetail,
            pathParameters: <String, String>{'id': '${order.id}'},
          ),
        );
      },
    );
  }
}

/// The full-screen error state with a retry affordance
/// (flutter-guidelines §Error Handling).
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// The empty state shown when the caller has placed no orders yet.
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('You have no orders yet.'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../product/widgets/next_page_footer.dart';
import '../providers/order_list_provider.dart';
import '../repositories/order_repository.dart';
import '../widgets/order_card.dart';

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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.retry,
          child: _buildBody(context, provider),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, OrderListProvider provider) {
    switch (provider.status) {
      case OrderListStatus.loading:
        return const _OrderListSkeleton();
      case OrderListStatus.error:
        return AppErrorState(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: provider.retry,
        );
      case OrderListStatus.ready:
        if (provider.isEmpty) {
          return AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            message: 'Orders you place will show up here.',
            actionLabel: 'Start shopping',
            onAction: () => context.goNamed(AppRoute.catalog),
          );
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
        return OrderCard(
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

/// The loading state: a plausible number of [ListTileSkeleton] rows in place
/// of the eventual order cards (design/03 §25, design/04 §1.2) — never a
/// centred spinner.
class _OrderListSkeleton extends StatelessWidget {
  const _OrderListSkeleton();

  static const int _rowCount = 5;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      itemCount: _rowCount,
      itemBuilder: (context, index) => const ListTileSkeleton(),
    );
  }
}

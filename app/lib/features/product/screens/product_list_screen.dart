import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_chips.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/search_field.dart';
import '../../cart/widgets/cart_badge.dart';
import '../models/brand_response.dart';
import '../models/category_response.dart';
import '../providers/product_list_provider.dart';
import '../repositories/brand_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';
import '../widgets/next_page_footer.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filter_sheet.dart';
import '../widgets/product_grid.dart';

/// The anonymous catalog — the app's landing surface (assumption 4). It owns a
/// single [ProductListProvider] built from the injected repositories and loads
/// the first page on mount; the repositories arrive from the composition root so
/// no widget constructs a `Dio` (flutter-guidelines §Networking).
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({
    super.key,
    required this.productRepository,
    required this.categoryRepository,
    required this.brandRepository,
  });

  final ProductRepository productRepository;
  final CategoryRepository categoryRepository;
  final BrandRepository brandRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProductListProvider>(
      create: (_) => ProductListProvider(
        productRepository,
        categoryRepository,
        brandRepository,
      )..loadInitial(),
      child: const _ProductListView(),
    );
  }
}

/// Renders the catalog (design/04 §4.2) and drives infinite scrolling: it
/// loads the next page when the scroll position nears the bottom (the
/// provider guards against duplicate and surplus requests). Search, filter
/// and sort state all live on [ProductListProvider] — this widget only
/// presents it and reports changes back through the provider's existing
/// setters.
class _ProductListView extends StatefulWidget {
  const _ProductListView();

  @override
  State<_ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<_ProductListView> {
  final ScrollController _scrollController = ScrollController();

  static const double _loadMoreThreshold = 200;

  // Bumped only by "Clear filters", to force a fresh `SearchField` (a new
  // key remounts it so its internal controller picks up the cleared
  // `initialValue`) — `SearchField` is otherwise intentionally uncontrolled
  // beyond its first build, exactly like every other consumer of it.
  int _searchGeneration = 0;

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
      context.read<ProductListProvider>().loadNextPage();
    }
  }

  /// Loads the next page when the current list is too short to scroll: a page
  /// smaller than the viewport would otherwise never fire [_onScroll]. Runs
  /// after layout so the scroll extent is known; the provider stops once the
  /// last page is reached.
  void _autoLoadIfNotScrollable() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.maxScrollExtent == 0) {
      context.read<ProductListProvider>().loadNextPage();
    }
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    ProductListProvider provider,
  ) async {
    final result = await showModalBottomSheet<ProductFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductFilterSheet(
        brands: provider.brands,
        categories: provider.categories,
        initialBrandId: provider.brandId,
        initialCategoryId: provider.categoryId,
        initialSort: provider.sort,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final listProvider = context.read<ProductListProvider>();
    if (result.brandId != provider.brandId) {
      await listProvider.setBrand(result.brandId);
    }
    if (result.categoryId != provider.categoryId) {
      await listProvider.setCategory(result.categoryId);
    }
    if (result.sort != provider.sort) {
      await listProvider.setSort(result.sort);
    }
  }

  Future<void> _clearFilters(
    BuildContext context,
    ProductListProvider provider,
  ) async {
    final listProvider = context.read<ProductListProvider>();
    if (provider.searchText.isNotEmpty) {
      setState(() => _searchGeneration++);
      await listProvider.setSearchText('');
    }
    if (provider.brandId != null) {
      await listProvider.setBrand(null);
    }
    if (provider.categoryId != null) {
      await listProvider.setCategory(null);
    }
    if (provider.sort != null) {
      await listProvider.setSort(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductListProvider>();
    if (provider.status == ProductListStatus.ready && !provider.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoLoadIfNotScrollable(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('FootVerse'),
        actions: <Widget>[
          const CartBadge(),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Account',
            onPressed: () => context.goNamed(AppRoute.account),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.retry,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SearchField(
                        key: ValueKey(_searchGeneration),
                        initialValue: provider.searchText,
                        onSearch: context
                            .read<ProductListProvider>()
                            .setSearchText,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      tooltip: 'Filter and sort',
                      onPressed: () => _openFilterSheet(context, provider),
                    ),
                  ],
                ),
              ),
              _ActiveFilters(provider: provider),
              Expanded(child: _buildBody(context, provider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProductListProvider provider) {
    switch (provider.status) {
      case ProductListStatus.loading:
        return const _ProductGridSkeleton();
      case ProductListStatus.error:
        return AppErrorState(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: provider.retry,
        );
      case ProductListStatus.ready:
        if (provider.isEmpty) {
          return AppEmptyState(
            icon: Icons.search_off,
            title: 'No products match your filters',
            message: 'Try removing a filter or changing your search.',
            actionLabel: 'Clear filters',
            onAction: () => _clearFilters(context, provider),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ProductGrid(
                products: provider.products,
                controller: _scrollController,
                onProductTap: (product) => context.goNamed(
                  AppRoute.productDetail,
                  pathParameters: <String, String>{'id': '${product.id}'},
                ),
              ),
            ),
            if (provider.loadingNextPage || provider.nextPageError != null)
              NextPageFooter(
                loading: provider.loadingNextPage,
                error: provider.nextPageError?.message,
                onRetry: context.read<ProductListProvider>().loadNextPage,
              ),
          ],
        );
    }
  }
}

/// The active-filter row (design/03 §7, design/04 §4.2): one removable
/// [ActiveFilterChip] per applied dimension — brand, category, and sort —
/// scrolling horizontally, shown only when at least one is set. Removing a
/// chip re-runs the query immediately through the same provider setter the
/// filter sheet uses.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.provider});

  final ProductListProvider provider;

  static String _sortLabel(ProductSort sort) {
    switch (sort) {
      case ProductSort.createdAt:
        return 'Newest';
      case ProductSort.basePrice:
        return 'Price';
      case ProductSort.name:
        return 'Name';
    }
  }

  static BrandResponse? _brandById(List<BrandResponse> brands, int id) {
    for (final brand in brands) {
      if (brand.id == id) {
        return brand;
      }
    }
    return null;
  }

  static CategoryResponse? _categoryById(
    List<CategoryResponse> categories,
    int id,
  ) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final brandId = provider.brandId;
    final categoryId = provider.categoryId;
    final sort = provider.sort;
    if (brandId == null && categoryId == null && sort == null) {
      return const SizedBox.shrink();
    }

    final listProvider = context.read<ProductListProvider>();
    final chips = <Widget>[
      if (brandId != null)
        ActiveFilterChip(
          label: _brandById(provider.brands, brandId)?.name ?? 'Brand',
          onRemove: () => listProvider.setBrand(null),
        ),
      if (categoryId != null)
        ActiveFilterChip(
          label:
              _categoryById(provider.categories, categoryId)?.name ??
              'Category',
          onRemove: () => listProvider.setCategory(null),
        ),
      if (sort != null)
        ActiveFilterChip(
          label: _sortLabel(sort),
          onRemove: () => listProvider.setSort(null),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The loading state (design/03 §24–25): a skeleton grid matching
/// [ProductGrid]'s own responsive column count and card geometry, so the
/// loading-to-ready transition has no layout jump. `ProductGrid` has no
/// skeleton mode of its own (design/03 §5 defines only the ready-content
/// grid), so this mirrors its column/aspect-ratio maths against the same
/// public tokens ([AppBreakpoints], [AppSpacing]) and the same public
/// [ProductCard.infoBlockHeight] constant, without modifying `ProductGrid`.
class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  static const int _itemCount = 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outer) {
        final columns = _columnsFor(outer.maxWidth);
        final contentMaxWidth = _contentMaxWidthFor(outer.maxWidth);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: LayoutBuilder(
              builder: (context, inner) {
                final cellWidth =
                    (inner.maxWidth -
                        AppSpacing.md * 2 -
                        AppSpacing.sm * (columns - 1)) /
                    columns;
                final aspectRatio =
                    cellWidth / (cellWidth + ProductCard.infoBlockHeight);

                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: _itemCount,
                  itemBuilder: (context, index) => const ProductCardSkeleton(),
                );
              },
            ),
          ),
        );
      },
    );
  }

  static int _columnsFor(double width) {
    if (width >= AppBreakpoints.expanded) {
      return 4;
    }
    if (width >= AppBreakpoints.medium) {
      return 3;
    }
    return 2;
  }

  static double _contentMaxWidthFor(double width) {
    if (width >= AppBreakpoints.expanded) {
      return AppBreakpoints.expanded;
    }
    if (width >= AppBreakpoints.medium) {
      return AppBreakpoints.medium;
    }
    return double.infinity;
  }
}

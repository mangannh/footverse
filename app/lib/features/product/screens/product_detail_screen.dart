import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/price_text.dart';
import '../../../core/widgets/rating_display.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/widgets/add_to_cart_button.dart';
import '../../cart/widgets/cart_badge.dart';
import '../../profile/repositories/profile_repository.dart';
import '../../review/providers/review_provider.dart';
import '../../review/repositories/review_repository.dart';
import '../../review/widgets/review_write_section.dart';
import '../../wishlist/widgets/wishlist_toggle.dart';
import '../models/product_detail_response.dart';
import '../models/product_image_response.dart';
import '../models/product_summary_response.dart';
import '../models/product_variant_response.dart';
import '../models/product_variant_status.dart';
import '../providers/product_detail_provider.dart';
import '../repositories/product_repository.dart';
import '../widgets/next_page_footer.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image_gallery.dart';
import '../widgets/review_tile.dart';
import '../widgets/size_selector.dart';

/// The read-only product detail (sprint-6-plan item 11): images, the §9 detail
/// fields, the read-only variants, the server's live rating / review count, and
/// the paginated public reviews. It owns a single [ProductDetailProvider] built
/// from the injected repository and loads on mount; every call it makes is a
/// public `GET` — nothing is mutated.
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.productRepository,
    required this.reviewRepository,
    required this.profileRepository,
  });

  final int productId;
  final ProductRepository productRepository;
  final ReviewRepository reviewRepository;
  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductDetailProvider>(
          create: (_) =>
              ProductDetailProvider(productRepository, productId)..load(),
        ),
        // Created after the detail provider so its create can read it and wire the
        // public review reload; a guest never loads an identity (Design
        // Decision 3), so the write affordance falls back to routing to login.
        ChangeNotifierProvider<ReviewProvider>(
          create: (context) {
            final detailProvider = context.read<ProductDetailProvider>();
            final provider = ReviewProvider(
              reviewRepository: reviewRepository,
              profileRepository: profileRepository,
              productId: productId,
              onReviewsChanged: () => detailProvider.retryReviews(),
            );
            if (context.read<AuthProvider>().isAuthenticated) {
              provider.loadCurrentUser();
            }
            return provider;
          },
        ),
      ],
      child: _ProductDetailView(productRepository: productRepository),
    );
  }
}

/// Renders the detail and drives the review list's infinite scrolling: it loads
/// the next review page when the scroll position nears the bottom, and also when
/// a short first page cannot scroll (the provider guards duplicate / surplus
/// requests and stops at the last page).
class _ProductDetailView extends StatefulWidget {
  const _ProductDetailView({required this.productRepository});

  final ProductRepository productRepository;

  @override
  State<_ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<_ProductDetailView> {
  final ScrollController _scrollController = ScrollController();

  static const double _loadMoreThreshold = 200;

  // Variant selection is screen-local UI state — it is not provider state and no
  // ProductDetailProvider is created for it (sprint-7-plan item 07).
  int? _selectedVariantId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _selectVariant(int variantId) {
    setState(() => _selectedVariantId = variantId);
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
      context.read<ProductDetailProvider>().loadNextReviews();
    }
  }

  void _autoLoadIfNotScrollable() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.maxScrollExtent == 0) {
      context.read<ProductDetailProvider>().loadNextReviews();
    }
  }

  /// The selected variant, or null when none is selected.
  ProductVariantResponse? _selectedVariant(ProductDetailResponse detail) {
    final id = _selectedVariantId;
    if (id == null) {
      return null;
    }
    for (final variant in detail.variants) {
      if (variant.id == id) {
        return variant;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductDetailProvider>();
    if (provider.status == ProductDetailStatus.ready &&
        provider.reviewsStatus == ReviewsStatus.ready &&
        !provider.isReviewsEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoLoadIfNotScrollable(),
      );
    }
    final detail = provider.detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail?.name ?? 'Product'),
        actions: <Widget>[
          const CartBadge(),
          if (detail != null) WishlistToggle(productId: detail.id),
        ],
      ),
      body: SafeArea(child: _buildBody(context, provider)),
      bottomNavigationBar: detail == null || detail.variants.isEmpty
          ? null
          : _StickyAddToCartBar(
              variant: _selectedVariant(detail),
              selected: _selectedVariantId,
            ),
    );
  }

  Widget _buildBody(BuildContext context, ProductDetailProvider provider) {
    switch (provider.status) {
      case ProductDetailStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: DetailSkeleton(),
        );
      case ProductDetailStatus.error:
        if (provider.isNotFound) {
          return AppEmptyState(
            icon: Icons.search_off,
            title: 'Product not found',
            message:
                provider.error?.message ??
                'This product may have been removed.',
            actionLabel: 'Browse products',
            onAction: () => context.goNamed(AppRoute.catalog),
          );
        }
        return AppErrorState(
          message: provider.error?.message ?? 'Something went wrong',
          onRetry: context.read<ProductDetailProvider>().retry,
        );
      case ProductDetailStatus.ready:
        return CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _DetailBody(
                detail: provider.detail!,
                images: provider.images,
                selectedVariantId: _selectedVariantId,
                onSelectVariant: _selectVariant,
              ),
            ),
            // The review-owned write affordance, embedded above the public list
            // (sprint-9-plan item 05). It reads the loaded reviews to resolve the
            // caller's own review by userId; the review feature owns the writes.
            SliverToBoxAdapter(
              child: ReviewWriteSection(reviews: provider.reviews),
            ),
            ..._reviewSlivers(context, provider),
            // Related products (design/04 §4.4) come after the review list —
            // the existing product-list endpoint filtered by category, no new
            // endpoint.
            SliverToBoxAdapter(
              child: _RelatedProducts(
                productRepository: widget.productRepository,
                categoryId: provider.detail!.categoryId,
                excludeProductId: provider.detail!.id,
              ),
            ),
          ],
        );
    }
  }

  List<Widget> _reviewSlivers(
    BuildContext context,
    ProductDetailProvider provider,
  ) {
    switch (provider.reviewsStatus) {
      case ReviewsStatus.loading:
        return const <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: ListTileSkeleton(),
            ),
          ),
        ];
      case ReviewsStatus.error:
        return <Widget>[
          SliverToBoxAdapter(
            child: NextPageFooter(
              loading: false,
              error: provider.reviewsError?.message ?? 'Could not load reviews',
              onRetry: context.read<ProductDetailProvider>().retryReviews,
            ),
          ),
        ];
      case ReviewsStatus.ready:
        if (provider.isReviewsEmpty) {
          return const <Widget>[
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: Icons.rate_review_outlined,
                title: 'No reviews yet',
                message: 'Be the first to share what you think.',
              ),
            ),
          ];
        }
        final reviews = provider.reviews;
        final hasFooter =
            provider.loadingNextReviews || provider.nextReviewsError != null;
        return <Widget>[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ReviewTile(review: reviews[index]),
              childCount: reviews.length,
            ),
          ),
          if (hasFooter)
            SliverToBoxAdapter(
              child: NextPageFooter(
                loading: provider.loadingNextReviews,
                error: provider.nextReviewsError?.message,
                onRetry: context.read<ProductDetailProvider>().loadNextReviews,
              ),
            ),
        ];
    }
  }
}

/// The product's own information plus its selectable sizes and the reviews
/// header — everything above the review list. Everything here stays
/// read-only; add-to-cart lives in the sticky bottom bar instead
/// (design/04 §4.4).
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.images,
    required this.selectedVariantId,
    required this.onSelectVariant,
  });

  final ProductDetailResponse detail;
  final List<ProductImageResponse> images;
  final int? selectedVariantId;
  final ValueChanged<int> onSelectVariant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final description = detail.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ProductImageGallery(images: images),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                detail.brandName,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                detail.name,
                style: theme.textTheme.titleMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              PriceText(
                amount: detail.basePrice,
                variant: PriceVariant.emphasis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  RatingDisplay(
                    rating: detail.averageRating,
                    reviewCount: detail.reviewCount,
                  ),
                  if (!detail.available)
                    AppTag(
                      label: 'Out of stock',
                      icon: Icons.error_outline,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (description != null && description.isNotEmpty) ...<Widget>[
                _ExpandableDescription(description: description),
              ],
              SectionHeader(
                title: detail.variants.isEmpty ? 'Sizes' : 'Select size',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SizeSelector(
            variants: detail.variants,
            selectedVariantId: selectedVariantId,
            onSelect: onSelectVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SectionHeader(title: 'Reviews'),
        ),
      ],
    );
  }
}

/// The description, collapsed beyond three lines with a "Show more" / "Show
/// less" toggle (design/04 §4.4, design/05 §13 item 5 — `short`). Purely
/// presentational screen-local state — nothing is fetched or mutated.
class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.description});

  final String description;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  static const int _collapsedMaxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        AnimatedSize(
          duration: AppMotion.short,
          curve: AppMotion.standard,
          alignment: Alignment.topLeft,
          child: Text(
            widget.description,
            style: theme.textTheme.bodyMedium,
            maxLines: _expanded ? null : _collapsedMaxLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
              padding: EdgeInsets.zero,
            ),
            child: Text(_expanded ? 'Show less' : 'Show more'),
          ),
        ),
      ],
    );
  }
}

/// The sticky bottom add-to-cart bar (design/04 §4.4): moved out of the
/// scroll so the screen's one decision is always reachable, even while the
/// customer is reading reviews.
class _StickyAddToCartBar extends StatelessWidget {
  const _StickyAddToCartBar({required this.variant, required this.selected});

  final ProductVariantResponse? variant;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final variant = this.variant;
    // Client-side pre-check mirroring the frozen purchase rule for UX; the
    // server stays authoritative (business-rules → Shopping Cart).
    final purchasable =
        variant != null &&
        variant.status == ProductVariantStatus.active &&
        variant.stockQuantity > 0;
    return Material(
      elevation: AppElevation.sticky,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AddToCartButton(
            productVariantId: selected,
            purchasable: purchasable,
            onAdded: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Added to cart'),
                  action: SnackBarAction(
                    label: 'View cart',
                    onPressed: () => context.pushNamed(AppRoute.cart),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The horizontal related-products row (design/04 §4.4): the existing
/// product-list endpoint filtered by category — no new endpoint. This is a
/// small, secondary, read-only data block with no shared state, so it owns
/// its own screen-local async status rather than a new provider
/// (sprint-14-plan: "no new provider" is a sprint-wide constraint, and
/// `ProductDetailProvider` is frozen). A failed or empty fetch never blanks
/// the rest of the page — it just omits the whole section, the same
/// per-block-independent-failure pattern design/04 §4.1 specifies for Home.
class _RelatedProducts extends StatefulWidget {
  const _RelatedProducts({
    required this.productRepository,
    required this.categoryId,
    required this.excludeProductId,
  });

  final ProductRepository productRepository;
  final int categoryId;
  final int excludeProductId;

  @override
  State<_RelatedProducts> createState() => _RelatedProductsState();
}

enum _RelatedStatus { loading, ready, error }

class _RelatedProductsState extends State<_RelatedProducts> {
  _RelatedStatus _status = _RelatedStatus.loading;
  List<ProductSummaryResponse> _products = const <ProductSummaryResponse>[];

  static const int _fetchSize = 10;
  static const int _skeletonCount = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await widget.productRepository.searchProducts(
        categoryId: widget.categoryId,
        size: _fetchSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = page.content
            .where((product) => product.id != widget.excludeProductId)
            .toList();
        _status = _RelatedStatus.ready;
      });
    } on AppException {
      if (!mounted) {
        return;
      }
      setState(() => _status = _RelatedStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _RelatedStatus.error ||
        (_status == _RelatedStatus.ready && _products.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SectionHeader(title: 'Related products'),
        ),
        SizedBox(
          height: ProductCard.compactWidth + ProductCard.infoBlockHeight,
          child: _status == _RelatedStatus.loading
              ? _skeletonRow()
              : _productRow(context),
        ),
      ],
    );
  }

  Widget _skeletonRow() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: _skeletonCount,
      separatorBuilder: (context, index) =>
          const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, index) => const SizedBox(
        width: ProductCard.compactWidth,
        child: ProductCardSkeleton(),
      ),
    );
  }

  Widget _productRow(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: _products.length,
      separatorBuilder: (context, index) =>
          const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, index) {
        final product = _products[index];
        return ProductCard(
          product: product,
          variant: ProductCardVariant.compact,
          onTap: () => context.goNamed(
            AppRoute.productDetail,
            pathParameters: <String, String>{'id': '${product.id}'},
          ),
        );
      },
    );
  }
}

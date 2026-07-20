import 'package:flutter/material.dart';

import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/product_summary_response.dart';
import 'product_card.dart';

/// The responsive product grid (design/03 §5) that replaces the
/// single-column `ListView` in `ProductListScreen` (Task 08). **UI only** —
/// it holds no list state and reads no provider or repository; [products]
/// and [onProductTap] are supplied by the caller, the same shape as
/// `ProductFilterSheet` (design/03 §6).
///
/// Columns follow the responsive breakpoints (design/02 §11): 2 at
/// `compact`, 3 at `medium`, 4 at `expanded`. At `medium`/`expanded` the
/// grid's own content is additionally capped to [AppBreakpoints.medium] /
/// [AppBreakpoints.expanded] and centred — "only the product grid changes
/// column count" (design/02 §11 rule 2) still holds, because the cap applies
/// to the grid's content alone, not the screen around it.
///
/// Card heights are uniform by construction: every cell in the grid shares
/// one `childAspectRatio`, derived from the cell width and
/// [ProductCard.infoBlockHeight] — the component-tier constant `ProductCard`
/// exposes for exactly this purpose (design/03 §5).
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.controller,
  });

  final List<ProductSummaryResponse> products;

  /// Fired with the tapped product; the caller decides where to navigate.
  final ValueChanged<ProductSummaryResponse> onProductTap;

  /// Forwarded to the underlying scroll view so a caller can drive infinite
  /// scroll exactly as `ProductListScreen` already does with its own
  /// `ScrollController` — that pattern stays screen-owned
  /// (flutter-guidelines: state ownership).
  final ScrollController? controller;

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
                  controller: controller,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      onTap: () => onProductTap(product),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// design/02 §11: 2 columns below 600 dp, 3 from 600 dp, 4 from 840 dp.
  static int _columnsFor(double width) {
    if (width >= AppBreakpoints.expanded) {
      return 4;
    }
    if (width >= AppBreakpoints.medium) {
      return 3;
    }
    return 2;
  }

  /// design/02 §11: the grid's own content caps at 600 dp / 840 dp and
  /// centres beyond those widths; phones (`compact`) are never capped.
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

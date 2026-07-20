import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_chips.dart';
import '../../../core/widgets/section_header.dart';
import '../models/brand_response.dart';
import '../models/category_response.dart';
import '../repositories/product_repository.dart';

/// The draft selection [ProductFilterSheet] returns on Apply. `null` on any
/// field means "no filter" for that dimension — the same meaning `null`
/// already carries on `ProductListProvider`.
@immutable
class ProductFilterResult {
  const ProductFilterResult({this.brandId, this.categoryId, this.sort});

  final int? brandId;
  final int? categoryId;
  final ProductSort? sort;

  @override
  bool operator ==(Object other) {
    return other is ProductFilterResult &&
        other.brandId == brandId &&
        other.categoryId == categoryId &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(brandId, categoryId, sort);
}

/// The filter & sort bottom sheet that replaces the three permanent dropdowns
/// (design/03 §7, §20). **UI only** — it holds no list state, reads no
/// provider or repository, and fetches nothing; [brands] and [categories]
/// are supplied by the caller (already loaded by `ProductListProvider`).
///
/// Present it with `showModalBottomSheet`, `isScrollControlled: true` and
/// `backgroundColor: Colors.transparent` — this widget draws its own
/// surface, radius and drag handle. On Apply it pops with a
/// [ProductFilterResult]; every other dismissal (tap outside, drag down, the
/// close button) pops with `null`, meaning "no change".
class ProductFilterSheet extends StatefulWidget {
  const ProductFilterSheet({
    super.key,
    required this.brands,
    required this.categories,
    this.initialBrandId,
    this.initialCategoryId,
    this.initialSort,
  });

  final List<BrandResponse> brands;
  final List<CategoryResponse> categories;
  final int? initialBrandId;
  final int? initialCategoryId;
  final ProductSort? initialSort;

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late int? _brandId = widget.initialBrandId;
  late int? _categoryId = widget.initialCategoryId;
  late ProductSort? _sort = widget.initialSort;

  /// design/03 §20 — Bottom Sheet max height is a ratified 80 % of viewport,
  /// not a spacing token.
  static const double _maxHeightFraction = 0.8;

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

  void _apply() {
    Navigator.of(context).pop(
      ProductFilterResult(
        brandId: _brandId,
        categoryId: _categoryId,
        sort: _sort,
      ),
    );
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * _maxHeightFraction;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Close',
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: _close,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Brand'),
                      _ChipGroup<int?>(
                        options: <int?>[
                          null,
                          for (final brand in widget.brands) brand.id,
                        ],
                        labelOf: (id) => id == null
                            ? 'All'
                            : widget.brands
                                  .firstWhere((brand) => brand.id == id)
                                  .name,
                        selected: _brandId,
                        onChanged: (value) => setState(() => _brandId = value),
                      ),
                      const SectionHeader(title: 'Category'),
                      _ChipGroup<int?>(
                        options: <int?>[
                          null,
                          for (final category in widget.categories) category.id,
                        ],
                        labelOf: (id) => id == null
                            ? 'All'
                            : widget.categories
                                  .firstWhere((category) => category.id == id)
                                  .name,
                        selected: _categoryId,
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                      ),
                      const SectionHeader(title: 'Sort by'),
                      _ChipGroup<ProductSort?>(
                        options: <ProductSort?>[null, ...ProductSort.values],
                        labelOf: (sort) =>
                            sort == null ? 'Default' : _sortLabel(sort),
                        selected: _sort,
                        onChanged: (value) => setState(() => _sort = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppPrimaryButton(label: 'Apply', onPressed: _apply),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single-select row of [CategoryChip]s over [options] — exactly one is
/// selected at a time, matching the single-value brand/category/sort filter
/// dimensions `ProductListProvider` already exposes.
class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> options;
  final String Function(T option) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final option in options)
            CategoryChip(
              label: labelOf(option),
              selected: option == selected,
              onSelected: (_) => onChanged(option),
            ),
        ],
      ),
    );
  }
}

/// The always-present drag handle (design/03 §20).
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  static const double _width = 32;
  static const double _height = 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}

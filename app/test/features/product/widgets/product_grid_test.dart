import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_breakpoints.dart';
import 'package:footverse/core/theme/app_spacing.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/features/product/models/product_summary_response.dart';
import 'package:footverse/features/product/widgets/product_card.dart';
import 'package:footverse/features/product/widgets/product_grid.dart';

List<ProductSummaryResponse> _products(int count) => List.generate(
  count,
  (i) => ProductSummaryResponse(
    id: i,
    name: 'Product $i',
    basePrice: 1000000 + i * 10000,
    brandName: 'Brand $i',
    categoryName: 'Category',
    primaryImageUrl: null,
    averageRating: 4.5,
    available: true,
  ),
);

/// The default test viewport (800×600 logical px) is narrower than the
/// 1200 dp width the "content width cap" tests need to request via the
/// [SizedBox] below — [WidgetTester.pumpWidget] otherwise clamps that
/// `SizedBox`'s width down to whatever the test window actually offers.
/// `devicePixelRatio: 1.0` keeps physical and logical pixels identical, so
/// [width] can be compared directly against the tokens.
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  List<ProductSummaryResponse>? products,
  ValueChanged<ProductSummaryResponse>? onProductTap,
}) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 800,
          child: ProductGrid(
            products: products ?? _products(8),
            onProductTap: onProductTap ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

SliverGridDelegateWithFixedCrossAxisCount _delegateOf(WidgetTester tester) {
  final gridView = tester.widget<GridView>(find.byType(GridView));
  return gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  group('ProductGrid — responsive columns (design/02 §11, design/03 §5)', () {
    testWidgets('2 columns below the medium breakpoint (compact)', (
      tester,
    ) async {
      await _pump(tester, width: AppBreakpoints.medium - 1);

      expect(_delegateOf(tester).crossAxisCount, 2);
    });

    testWidgets('3 columns at the medium breakpoint', (tester) async {
      await _pump(tester, width: AppBreakpoints.medium);

      expect(_delegateOf(tester).crossAxisCount, 3);
    });

    testWidgets('4 columns at the expanded breakpoint', (tester) async {
      await _pump(tester, width: AppBreakpoints.expanded);

      expect(_delegateOf(tester).crossAxisCount, 4);
    });
  });

  group('ProductGrid — content width cap (design/02 §11)', () {
    testWidgets('phones are never capped', (tester) async {
      await _pump(tester, width: 360);

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      expect(
        constrainedBoxes.any(
          (box) => box.constraints.maxWidth == double.infinity,
        ),
        isTrue,
      );
    });

    testWidgets(
      'content caps at 840 dp and centres beyond the expanded breakpoint',
      (tester) async {
        await _pump(tester, width: 1200);

        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        expect(
          constrainedBoxes.any(
            (box) => box.constraints.maxWidth == AppBreakpoints.expanded,
          ),
          isTrue,
        );
        expect(find.byType(Center), findsWidgets);
      },
    );
  });

  group('ProductGrid — layout tokens (design/03 §5)', () {
    testWidgets('outer padding is AppSpacing.md; gutters are AppSpacing.sm', (
      tester,
    ) async {
      await _pump(tester, width: 360);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      expect(gridView.padding, const EdgeInsets.all(AppSpacing.md));

      final delegate = _delegateOf(tester);
      expect(delegate.mainAxisSpacing, AppSpacing.sm);
      expect(delegate.crossAxisSpacing, AppSpacing.sm);
    });
  });

  group('ProductGrid — card uniformity (design/03 §5)', () {
    testWidgets('every rendered card has the same size', (tester) async {
      await _pump(tester, width: 360, products: _products(4));

      final firstSize = tester.getSize(find.byType(ProductCard).first);
      final secondSize = tester.getSize(find.byType(ProductCard).at(1));
      expect(firstSize, secondSize);
    });
  });

  group('ProductGrid — interaction', () {
    testWidgets('tapping a card reports that exact product via onProductTap', (
      tester,
    ) async {
      ProductSummaryResponse? tapped;
      final products = _products(4);
      await _pump(
        tester,
        width: 360,
        products: products,
        onProductTap: (product) => tapped = product,
      );

      await tester.tap(find.byType(ProductCard).first);
      await tester.pump();

      expect(tapped, same(products.first));
    });
  });

  group('ProductGrid — no business logic (design/03 §0.3)', () {
    testWidgets('an empty list renders no cards and never throws', (
      tester,
    ) async {
      await _pump(tester, width: 360, products: const []);

      expect(tester.takeException(), isNull);
      expect(find.byType(ProductCard), findsNothing);
    });
  });
}

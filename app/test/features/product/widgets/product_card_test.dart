import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_network_image.dart';
import 'package:footverse/core/widgets/app_tag.dart';
import 'package:footverse/core/widgets/price_text.dart';
import 'package:footverse/core/widgets/rating_display.dart';
import 'package:footverse/features/product/models/product_summary_response.dart';
import 'package:footverse/features/product/widgets/product_card.dart';

const _available = ProductSummaryResponse(
  id: 1,
  name: 'Air Zoom Pegasus 40',
  basePrice: 1250000,
  brandName: 'Nike',
  categoryName: 'Running',
  primaryImageUrl: 'https://cdn.example.com/p1.jpg',
  averageRating: 4.5,
  available: true,
);

const _unavailable = ProductSummaryResponse(
  id: 2,
  name: 'Ultraboost 22',
  basePrice: 3200000,
  brandName: 'Adidas',
  categoryName: 'Running',
  primaryImageUrl: null,
  averageRating: 0,
  available: false,
);

const _noRating = ProductSummaryResponse(
  id: 3,
  name: 'Gel-Kayano 30',
  basePrice: 4100000,
  brandName: 'Asics',
  categoryName: 'Running',
  primaryImageUrl: null,
  averageRating: 0,
  available: true,
);

/// Bounds width to [width] via a tight [SizedBox] — appropriate for the
/// [ProductCardVariant.grid] variant, which fills whatever width its parent
/// gives it. The [ProductCardVariant.compact] tests deliberately avoid this
/// helper: a tight outer width would out-constrain the card's own internal
/// fixed width.
Future<void> _pump(
  WidgetTester tester,
  ProductSummaryResponse product, {
  VoidCallback? onTap,
  double width = 200,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: ProductCard(product: product, onTap: onTap ?? () {}),
        ),
      ),
    ),
  );
}

void main() {
  group('ProductCard — structure (design/03 §4)', () {
    testWidgets('is image-led — uses AppNetworkImage', (tester) async {
      await _pump(tester, _available);

      expect(find.byType(AppNetworkImage), findsOneWidget);
    });

    testWidgets('renders the price only through PriceText', (tester) async {
      await _pump(tester, _available);

      expect(find.byType(PriceText), findsOneWidget);
      expect(find.text('₫1,250,000'), findsOneWidget);
    });

    testWidgets('never interpolates the raw basePrice as a string', (
      tester,
    ) async {
      await _pump(tester, _available);

      expect(find.textContaining('1250000.0'), findsNothing);
      expect(find.textContaining('1250000'), findsNothing);
    });

    testWidgets(
      'information order is image → brand → name → price → rating/availability',
      (tester) async {
        await _pump(tester, _available);

        final imageTop = tester.getTopLeft(find.byType(AppNetworkImage)).dy;
        final brandTop = tester.getTopLeft(find.text('Nike')).dy;
        final nameTop = tester.getTopLeft(find.text('Air Zoom Pegasus 40')).dy;
        final priceTop = tester.getTopLeft(find.byType(PriceText)).dy;
        final metaTop = tester.getTopLeft(find.byType(RatingDisplay)).dy;

        expect(imageTop, lessThan(brandTop));
        expect(brandTop, lessThan(nameTop));
        expect(nameTop, lessThan(priceTop));
        expect(priceTop, lessThan(metaTop));
      },
    );

    testWidgets('the whole card is one tap target', (tester) async {
      var tapped = false;
      await _pump(tester, _available, onTap: () => tapped = true);

      await tester.tap(find.byType(ProductCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('ProductCard — availability states (design/03 §4)', () {
    testWidgets('an available product shows "In stock" at full image opacity', (
      tester,
    ) async {
      await _pump(tester, _available);

      expect(find.text('In stock'), findsOneWidget);
      expect(find.text('Out of stock'), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets(
      'an unavailable product dims the image and shows the "Out of stock" tag — never opacity alone',
      (tester) async {
        await _pump(tester, _unavailable);

        final opacity = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacity.opacity, lessThan(1.0));
        expect(find.text('Out of stock'), findsOneWidget);
        expect(find.byType(AppTag), findsOneWidget);
        expect(find.text('In stock'), findsNothing);
      },
    );

    testWidgets('a product with no rating still shows availability', (
      tester,
    ) async {
      await _pump(tester, _noRating);

      expect(find.text('In stock'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });
  });

  group('ProductCard — no wishlist toggle (design/03 §4)', () {
    testWidgets('never renders a wishlist icon', (tester) async {
      await _pump(tester, _available);

      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });

  group('ProductCard — accessibility (design/03 §4)', () {
    // A single semantics node is not reachable through `find.byType(ProductCard)`
    // — its element resolves to `Card`'s own render object, an ancestor of the
    // merged node — so these tests locate it directly by its composite label,
    // exactly how a screen reader would encounter it.
    final compositeLabel = RegExp(
      r'Nike[\s\S]*Air Zoom Pegasus 40[\s\S]*Vietnamese dong'
      r'[\s\S]*Rated 4\.5 out of 5[\s\S]*In stock',
    );

    testWidgets('emits exactly one semantics node summarising the card', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _available);

      // Exactly one node matches the full composite description — brand,
      // name, price, rating and availability all on the same node.
      expect(find.bySemanticsLabel(compositeLabel), findsOneWidget);

      handle.dispose();
    });

    testWidgets(
      'that node is announced as a button and has no child semantics nodes',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _available);

        final semantics = tester.getSemantics(
          find.bySemanticsLabel(compositeLabel),
        );
        expect(semantics.flagsCollection.isButton, isTrue);
        expect(semantics.childrenCount, 0);

        handle.dispose();
      },
    );
  });

  group('ProductCard — variants (design/03 §4)', () {
    testWidgets('grid fills the width its parent gives it', (tester) async {
      await _pump(tester, _available, width: 180);

      final size = tester.getSize(find.byType(ProductCard));
      expect(size.width, 180);
    });

    testWidgets('compact uses a fixed component-tier width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductCard(
              product: _available,
              onTap: () {},
              variant: ProductCardVariant.compact,
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(ProductCard));
      expect(size.width, ProductCard.compactWidth);
    });
  });
}

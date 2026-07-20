import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/features/product/models/product_variant_response.dart';
import 'package:footverse/features/product/models/product_variant_status.dart';
import 'package:footverse/features/product/widgets/size_selector.dart';

const _oneColorVariants = <ProductVariantResponse>[
  ProductVariantResponse(
    id: 1,
    color: 'Black',
    size: '40',
    price: 1500000,
    stockQuantity: 5,
    status: ProductVariantStatus.active,
    sku: 'SKU-1',
  ),
  ProductVariantResponse(
    id: 2,
    color: 'Black',
    size: '41',
    price: 1500000,
    stockQuantity: 0,
    status: ProductVariantStatus.active,
    sku: 'SKU-2',
  ),
  ProductVariantResponse(
    id: 3,
    color: 'Black',
    size: '42',
    price: 1500000,
    stockQuantity: 3,
    status: ProductVariantStatus.inactive,
    sku: 'SKU-3',
  ),
];

const _twoColorVariants = <ProductVariantResponse>[
  ProductVariantResponse(
    id: 1,
    color: 'Black',
    size: '40',
    price: 1500000,
    stockQuantity: 5,
    status: ProductVariantStatus.active,
    sku: 'SKU-1',
  ),
  ProductVariantResponse(
    id: 2,
    color: 'White',
    size: '40',
    price: 1500000,
    stockQuantity: 5,
    status: ProductVariantStatus.active,
    sku: 'SKU-2',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required List<ProductVariantResponse> variants,
  int? selectedVariantId,
  ValueChanged<int>? onSelect,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizeSelector(
          variants: variants,
          selectedVariantId: selectedVariantId,
          onSelect: onSelect,
        ),
      ),
    ),
  );
}

void main() {
  group('SizeSelector — vocabulary (design/03 §8)', () {
    testWidgets('never shows SKU, Stock, Active, or Inactive', (tester) async {
      await _pump(tester, variants: _oneColorVariants, onSelect: (_) {});

      expect(find.textContaining('SKU'), findsNothing);
      expect(find.textContaining('Stock'), findsNothing);
      expect(find.text('Active'), findsNothing);
      expect(find.text('Inactive'), findsNothing);
    });

    testWidgets(
      'shows the size for every variant, including unavailable ones',
      (tester) async {
        await _pump(tester, variants: _oneColorVariants, onSelect: (_) {});

        expect(find.text('40'), findsOneWidget);
        expect(find.text('41'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
      },
    );
  });

  group('SizeSelector — colour grouping (design/03 §8)', () {
    testWidgets('a single colour renders no colour sub-heading', (
      tester,
    ) async {
      await _pump(tester, variants: _oneColorVariants, onSelect: (_) {});

      expect(find.text('Black'), findsNothing);
    });

    testWidgets('multiple colours render a sub-heading per colour', (
      tester,
    ) async {
      await _pump(tester, variants: _twoColorVariants, onSelect: (_) {});

      expect(find.text('Black'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
    });
  });

  group('SizeSelector — tile states (design/03 §8)', () {
    testWidgets('tapping an available size selects it', (tester) async {
      int? selected;
      await _pump(
        tester,
        variants: _oneColorVariants,
        onSelect: (id) => selected = id,
      );

      await tester.tap(find.text('40'));
      await tester.pump();

      expect(selected, 1);
    });

    testWidgets(
      'an out-of-stock size (stockQuantity: 0) stays visible but is not tappable',
      (tester) async {
        int? selected;
        await _pump(
          tester,
          variants: _oneColorVariants,
          onSelect: (id) => selected = id,
        );

        await tester.tap(find.text('41'));
        await tester.pump();

        expect(selected, isNull);
      },
    );

    testWidgets('an inactive size stays visible but is not tappable', (
      tester,
    ) async {
      int? selected;
      await _pump(
        tester,
        variants: _oneColorVariants,
        onSelect: (id) => selected = id,
      );

      await tester.tap(find.text('42'));
      await tester.pump();

      expect(selected, isNull);
    });

    testWidgets(
      'an unavailable tile remains reachable in the semantics tree, marked disabled',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, variants: _oneColorVariants, onSelect: (_) {});

        // Findable at all (not excluded/hidden) is the reachability contract
        // design/03 §8 asks for — a hidden size is indistinguishable from
        // one that was never made.
        final semantics = tester.getSemantics(
          find.bySemanticsLabel('Size 41, out of stock'),
        );
        expect(semantics.flagsCollection.isEnabled.toBoolOrNull(), isFalse);

        handle.dispose();
      },
    );

    testWidgets('a selected tile is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        variants: _oneColorVariants,
        selectedVariantId: 1,
        onSelect: (_) {},
      );

      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Size 40, available'),
      );
      expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);

      handle.dispose();
    });
  });

  group('SizeSelector — read-only mode', () {
    testWidgets('without onSelect, tapping an in-stock size never throws', (
      tester,
    ) async {
      await _pump(tester, variants: _oneColorVariants);

      await tester.tap(find.text('40'), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('SizeSelector — empty', () {
    testWidgets('an empty variant list renders a message, never throws', (
      tester,
    ) async {
      await _pump(tester, variants: const <ProductVariantResponse>[]);

      expect(tester.takeException(), isNull);
      expect(find.text('No sizes available.'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/features/product/models/brand_response.dart';
import 'package:footverse/features/product/models/category_response.dart';
import 'package:footverse/features/product/repositories/product_repository.dart';
import 'package:footverse/features/product/widgets/product_filter_sheet.dart';

const _brands = [
  BrandResponse(id: 1, name: 'Nike'),
  BrandResponse(id: 2, name: 'Adidas'),
];
const _categories = [
  CategoryResponse(id: 10, name: 'Sneakers'),
  CategoryResponse(id: 11, name: 'Boots'),
];

/// Opens [ProductFilterSheet] exactly the way Task 08's screen is expected
/// to, and hands back the [ValueNotifier] the eventual pop result lands in.
Future<ValueNotifier<ProductFilterResult?>> _openSheet(
  WidgetTester tester, {
  int? initialBrandId,
  int? initialCategoryId,
  ProductSort? initialSort,
}) async {
  final resultHolder = ValueNotifier<ProductFilterResult?>(null);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              resultHolder.value =
                  await showModalBottomSheet<ProductFilterResult>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ProductFilterSheet(
                      brands: _brands,
                      categories: _categories,
                      initialBrandId: initialBrandId,
                      initialCategoryId: initialCategoryId,
                      initialSort: initialSort,
                    ),
                  );
            },
            child: const Text('Open filters'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open filters'));
  await tester.pumpAndSettle();
  return resultHolder;
}

/// Taps a chip by its label, scrolling it into view first — the sheet's
/// selection groups live inside a `SingleChildScrollView`, and a chip
/// further down (e.g. a sort option) may start outside the visible viewport
/// in the default test surface size.
Future<void> _tapChipLabel(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('ProductFilterSheet — UI only, no list state (design/03 §7, §20)', () {
    testWidgets(
      'renders without any Provider or repository in the widget tree',
      (tester) async {
        // No ChangeNotifierProvider, no Repository instance anywhere in this
        // tree — if the sheet needed one, this test would throw at build time.
        await _openSheet(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Filters'), findsOneWidget);
      },
    );

    testWidgets(
      'renders the brand, category, and sort options passed in — nothing fetched',
      (tester) async {
        await _openSheet(tester);

        expect(find.text('Nike'), findsOneWidget);
        expect(find.text('Adidas'), findsOneWidget);
        expect(find.text('Sneakers'), findsOneWidget);
        expect(find.text('Boots'), findsOneWidget);
        expect(find.text('Newest'), findsOneWidget);
        expect(find.text('Price'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
      },
    );
  });

  group(
    'ProductFilterSheet — returns its result via Navigator.pop (design/03 §7)',
    () {
      testWidgets(
        'Apply pops with a ProductFilterResult reflecting the tapped selections',
        (tester) async {
          final result = await _openSheet(tester);

          await _tapChipLabel(tester, 'Nike');
          await _tapChipLabel(tester, 'Sneakers');
          await _tapChipLabel(tester, 'Newest');
          await tester.tap(find.text('Apply'));
          await tester.pumpAndSettle();

          expect(
            result.value,
            const ProductFilterResult(
              brandId: 1,
              categoryId: 10,
              sort: ProductSort.createdAt,
            ),
          );
        },
      );

      testWidgets('the close button pops with null — "no change"', (
        tester,
      ) async {
        final result = await _openSheet(tester);

        await _tapChipLabel(tester, 'Nike');
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        expect(result.value, isNull);
      });

      testWidgets(
        'Apply with every dimension left at "All"/"Default" pops an all-null result',
        (tester) async {
          final result = await _openSheet(tester);

          await tester.tap(find.text('Apply'));
          await tester.pumpAndSettle();

          expect(result.value, const ProductFilterResult());
        },
      );
    },
  );

  group('ProductFilterSheet — pre-selection from initial values', () {
    testWidgets('the initial brand/category/sort chips start selected', (
      tester,
    ) async {
      await _openSheet(
        tester,
        initialBrandId: 2,
        initialCategoryId: 11,
        initialSort: ProductSort.name,
      );

      final adidasChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Adidas'),
          matching: find.byType(FilterChip),
        ),
      );
      final bootsChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Boots'),
          matching: find.byType(FilterChip),
        ),
      );
      final nameChip = tester.widget<FilterChip>(
        find.ancestor(of: find.text('Name'), matching: find.byType(FilterChip)),
      );

      expect(adidasChip.selected, isTrue);
      expect(bootsChip.selected, isTrue);
      expect(nameChip.selected, isTrue);
    });

    testWidgets(
      'applying without changing anything preserves the initial selection',
      (tester) async {
        final result = await _openSheet(
          tester,
          initialBrandId: 2,
          initialCategoryId: 11,
          initialSort: ProductSort.name,
        );

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(
          result.value,
          const ProductFilterResult(
            brandId: 2,
            categoryId: 11,
            sort: ProductSort.name,
          ),
        );
      },
    );
  });

  group('ProductFilterSheet — single-select per dimension', () {
    testWidgets('selecting a second brand deselects the first', (tester) async {
      await _openSheet(tester);

      await _tapChipLabel(tester, 'Nike');
      await _tapChipLabel(tester, 'Adidas');

      final nikeChip = tester.widget<FilterChip>(
        find.ancestor(of: find.text('Nike'), matching: find.byType(FilterChip)),
      );
      final adidasChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Adidas'),
          matching: find.byType(FilterChip),
        ),
      );

      expect(nikeChip.selected, isFalse);
      expect(adidasChip.selected, isTrue);
    });
  });
}

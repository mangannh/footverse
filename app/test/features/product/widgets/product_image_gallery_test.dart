import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/app_network_image.dart';
import 'package:footverse/features/product/models/product_image_response.dart';
import 'package:footverse/features/product/widgets/product_image_gallery.dart';

ProductImageResponse _image(int id, {int displayOrder = 0}) =>
    ProductImageResponse(
      id: id,
      imageUrl: 'https://cdn.example.com/p$id.jpg',
      displayOrder: displayOrder,
      isPrimary: displayOrder == 0,
    );

Future<void> _pump(
  WidgetTester tester,
  List<ProductImageResponse> images, {
  double width = 400,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: ProductImageGallery(images: images),
        ),
      ),
    ),
  );
}

void main() {
  group('ProductImageGallery — imagery contract (design/03 §23, §4.4)', () {
    testWidgets('a single image renders full-bleed at the given width', (
      tester,
    ) async {
      await _pump(tester, <ProductImageResponse>[_image(1)], width: 320);

      final size = tester.getSize(find.byType(AppNetworkImage).first);
      expect(size.width, 320);
      expect(size.height, 320);
    });

    testWidgets(
      'an empty image list shows one placeholder frame, never throws',
      (tester) async {
        await _pump(tester, const <ProductImageResponse>[], width: 320);

        expect(tester.takeException(), isNull);
        expect(find.byType(AppNetworkImage), findsOneWidget);
        final size = tester.getSize(find.byType(AppNetworkImage));
        expect(size.width, 320);
        expect(size.height, 320);
      },
    );
  });

  group('ProductImageGallery — paging (design/03 §23, design/04 §4.4)', () {
    testWidgets('renders a PageView, not a plain horizontal ListView', (
      tester,
    ) async {
      await _pump(tester, <ProductImageResponse>[_image(1), _image(2)]);

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('a single image shows no page dots', (tester) async {
      await _pump(tester, <ProductImageResponse>[_image(1)]);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.bySemanticsLabel('Image 1 of 1'), findsNothing);
    });

    testWidgets('multiple images show one dot per image', (tester) async {
      await _pump(tester, <ProductImageResponse>[
        _image(1),
        _image(2),
        _image(3),
      ]);

      expect(find.bySemanticsLabel('Image 1 of 3'), findsOneWidget);
    });

    testWidgets('swiping to the next page updates the dot indicator', (
      tester,
    ) async {
      await _pump(tester, <ProductImageResponse>[_image(1), _image(2)]);

      expect(find.bySemanticsLabel('Image 1 of 2'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Image 2 of 2'), findsOneWidget);
    });
  });
}

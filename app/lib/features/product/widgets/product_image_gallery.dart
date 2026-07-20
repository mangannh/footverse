import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_network_image.dart';
import '../models/product_image_response.dart';

/// The product's image gallery (design/03 §23, design/04 §4.4): full-bleed,
/// 1:1, paged, with page indicator dots. The caller passes images already
/// ordered by `displayOrder` (dto-spec §9); a product with no image shows a
/// single placeholder frame at the same geometry.
class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({super.key, required this.images});

  final List<ProductImageResponse> images;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        if (images.isEmpty) {
          return AppNetworkImage(url: null, width: size);
        }
        return Column(
          children: <Widget>[
            SizedBox(
              width: size,
              height: size,
              child: PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) =>
                    AppNetworkImage(url: images[index].imageUrl, width: size),
              ),
            ),
            if (images.length > 1) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              _PageDots(count: images.length, index: _page),
            ],
          ],
        );
      },
    );
  }
}

/// The gallery's page indicator (design/05 §13 item 16 — the gallery-page
/// transition; the dots themselves are a static readout of that state, not
/// a separate animation).
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  static const double _dotSize = 6;
  static const double _activeDotSize = 8;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Image ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.xxs),
            Container(
              width: i == index ? _activeDotSize : _dotSize,
              height: i == index ? _activeDotSize : _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

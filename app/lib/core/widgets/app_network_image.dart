import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import 'app_skeleton.dart';

/// The single choke point for every network image in FootVerse
/// (design/02 §2.5, sprint-14-plan Task 04).
///
/// Wraps `cached_network_image` in exactly one place, so caching, placeholder,
/// and error-fallback behaviour are identical everywhere a network image
/// appears, and a future cache-package swap is a one-file change. No
/// `cached_network_image` type appears anywhere in this widget's public
/// API — only plain Flutter/Dart types ([String], [double]).
///
/// [width] is **required**, so an unbounded instance cannot be constructed —
/// there is no code path that omits it. [height] defaults to [width], giving
/// the 1:1 square frame the imagery contract specifies by default; pass
/// [height] explicitly only when a component has a genuine, documented
/// reason to deviate from square.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    required this.width,
    double? height,
  }) : assert(
         width > 0 && width < double.infinity,
         'AppNetworkImage.width must be finite and positive',
       ),
       assert(
         height == null || (height > 0 && height < double.infinity),
         'AppNetworkImage.height must be finite and positive',
       ),
       height = height ?? width;

  /// The image URL, exactly as delivered by the server. `null` or empty
  /// renders the standard placeholder — never throws.
  final String? url;

  /// The frame's width. Always required, so every instance is bounded.
  final double width;

  /// The frame's height. Defaults to [width] (design/02 §2.5: 1:1 default).
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = this.url;

    final Widget image = (url == null || url.isEmpty)
        ? _ImagePlaceholder(width: width, height: height)
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) => AppSkeleton(
              builder: (context, shimmer) => _ImageSkeletonBone(
                shimmer: shimmer,
                width: width,
                height: height,
              ),
            ),
            errorWidget: (context, url, error) =>
                _ImagePlaceholder(width: width, height: height),
          );

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: image,
        ),
      ),
    );
  }
}

/// The standard placeholder — identical treatment for a null/empty [url]
/// and for a failed load, so a broken image never looks different from "no
/// image" (design/02 §2.5). No exception text, no red error colour, no
/// stack trace, no retry affordance — just the neutral placeholder icon.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: colorScheme.outline,
        ),
      ),
    );
  }
}

/// A single skeleton "bone" the size of the image frame — reuses
/// [AppSkeleton]'s shimmer/delay/reduced-motion mechanism (Task 03) rather
/// than a second skeleton implementation.
class _ImageSkeletonBone extends StatelessWidget {
  const _ImageSkeletonBone({
    required this.shimmer,
    required this.width,
    required this.height,
  });

  final Animation<double>? shimmer;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shimmer = this.shimmer;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colorScheme.surfaceContainerHighest),
          if (shimmer != null)
            FadeTransition(
              opacity: shimmer,
              child: ColoredBox(color: colorScheme.surfaceContainerHigh),
            ),
        ],
      ),
    );
  }
}

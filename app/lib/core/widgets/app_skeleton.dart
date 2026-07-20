import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The shared skeleton mechanism (design/03 §25, design/05 §9).
///
/// Owns the three behaviours every skeleton needs, so no consumer
/// re-implements them: a ~200 ms show-delay (reusing [AppMotion.short] — a
/// dedicated delay token does not exist, and this is the token whose value
/// already matches the spec), a synchronized shimmer pulse across every bone
/// it renders, and a static fallback when [MediaQuery.disableAnimations] is
/// set. [builder] receives the shared shimmer [Animation] — `null` when
/// motion is reduced — to hand to each `_SkeletonBone` it composes.
///
/// This widget is the implementation detail behind [ProductCardSkeleton],
/// [ListTileSkeleton], [DetailSkeleton], and [TextLineSkeleton]; it is not
/// meant to be used directly outside this file.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, required this.builder});

  final Widget Function(BuildContext context, Animation<double>? shimmer)
  builder;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;
  Timer? _showDelay;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.skeletonCycle,
    );
    // A single non-reversing pass (0 → 1 → 0 within one repeat()) so the
    // controller always plays in one direction, never reverses, while still
    // producing a smooth breathing pulse (design/05 §9: "One direction").
    _shimmer = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(
        weight: 1,
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: AppMotion.standard)),
      ),
      TweenSequenceItem(
        weight: 1,
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: AppMotion.standard)),
      ),
    ]).animate(_controller);

    // Flashing a skeleton for a fast cached response is worse than showing
    // nothing (design/05 §5 Rule 1) — so nothing renders until this fires.
    _showDelay = Timer(AppMotion.short, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  void dispose() {
    _showDelay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      // Static fallback: the shared controller stops and `null` is handed
      // to every bone, so each renders its base tone only — no shimmer.
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return Semantics(label: 'Loading', child: widget.builder(context, null));
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
    return Semantics(
      label: 'Loading',
      child: widget.builder(context, _shimmer),
    );
  }
}

/// A single skeleton "bone" — a rounded rectangle in
/// `surfaceContainerHighest`, optionally overlaid with a
/// `surfaceContainerHigh` fade driven by [shimmer]. Colour and radius come
/// from tokens only; [width]/[height] are the one component-tier geometry
/// exception permitted by design/02 §1 for a component's own shapes.
class _SkeletonBone extends StatelessWidget {
  const _SkeletonBone({
    this.shimmer,
    this.width,
    this.height,
    this.borderRadius,
  });

  final Animation<double>? shimmer;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.sm);
    final shimmer = this.shimmer;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
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
      ),
    );
  }
}

/// A single skeleton text line (design/03 §25).
///
/// [widthFactor] varies a stacked line's length so a paragraph skeleton
/// doesn't read as a uniform block — the one parameter this shape genuinely
/// needs.
class TextLineSkeleton extends StatelessWidget {
  const TextLineSkeleton({super.key, this.widthFactor = 1.0});

  final double widthFactor;

  static const double _height = 12;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      builder: (context, shimmer) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: _SkeletonBone(shimmer: shimmer, height: _height),
      ),
    );
  }
}

/// A skeleton for a single list row: a leading avatar bone and two stacked
/// text-line bones (design/03 §25).
class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key});

  static const double _avatarDiameter = 40;
  static const double _lineHeight = 12;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      builder: (context, shimmer) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SkeletonBone(
              shimmer: shimmer,
              width: _avatarDiameter,
              height: _avatarDiameter,
              borderRadius: BorderRadius.circular(_avatarDiameter / 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SkeletonBone(
                    shimmer: shimmer,
                    height: _lineHeight,
                    width: double.infinity,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBone(shimmer: shimmer, height: _lineHeight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton for a detail-page layout: a square image bone, a title bone,
/// and a short paragraph of line bones (design/03 §25).
///
/// Geometry is a plausible approximation, not final — the real
/// `ProductCard`/detail layout does not exist yet, so there is nothing to
/// match pixel-for-pixel until Task 07.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  static const double _titleHeight = 16;
  static const double _lineHeight = 12;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      builder: (context, shimmer) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _SkeletonBone(
              shimmer: shimmer,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBone(
            shimmer: shimmer,
            height: _titleHeight,
            width: double.infinity,
          ),
          const SizedBox(height: AppSpacing.sm),
          FractionallySizedBox(
            widthFactor: 0.4,
            alignment: Alignment.centerLeft,
            child: _SkeletonBone(shimmer: shimmer, height: _lineHeight),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBone(
            shimmer: shimmer,
            height: _lineHeight,
            width: double.infinity,
          ),
          const SizedBox(height: AppSpacing.xs),
          _SkeletonBone(
            shimmer: shimmer,
            height: _lineHeight,
            width: double.infinity,
          ),
          const SizedBox(height: AppSpacing.xs),
          FractionallySizedBox(
            widthFactor: 0.7,
            alignment: Alignment.centerLeft,
            child: _SkeletonBone(shimmer: shimmer, height: _lineHeight),
          ),
        ],
      ),
    );
  }
}

/// A skeleton for the image-led product card (design/03 §25, design/04
/// §4.2), tuned to `ProductCard`'s finished geometry (sprint-14-plan Task
/// 07, closing R-9): a square image bone, wrapped in the same
/// `AppSpacing.sm` padding as `ProductCard`'s info panel, followed by
/// brand / two name-line / price / rating-and-availability bones — the same
/// information order and the same outer padding as the real card, so the
/// loading-to-ready transition has no layout jump.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  static const double _labelLineHeight = 12;
  static const double _priceLineHeight = 16;
  static const double _metaLineHeight = 14;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      builder: (context, shimmer) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _SkeletonBone(
              shimmer: shimmer,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand.
                FractionallySizedBox(
                  widthFactor: 0.35,
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBone(
                    shimmer: shimmer,
                    height: _labelLineHeight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Product name — two lines, matching `maxLines: 2`.
                _SkeletonBone(
                  shimmer: shimmer,
                  height: _labelLineHeight,
                  width: double.infinity,
                ),
                const SizedBox(height: AppSpacing.xxs),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBone(
                    shimmer: shimmer,
                    height: _labelLineHeight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Price.
                FractionallySizedBox(
                  widthFactor: 0.4,
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBone(
                    shimmer: shimmer,
                    height: _priceLineHeight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Rating + availability.
                FractionallySizedBox(
                  widthFactor: 0.55,
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBone(
                    shimmer: shimmer,
                    height: _metaLineHeight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

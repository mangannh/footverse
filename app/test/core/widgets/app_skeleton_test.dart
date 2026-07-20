import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/widgets/app_skeleton.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Scopes a finder to descendants of [ancestor] — `MaterialApp` itself
/// renders its own `ColoredBox`/`FadeTransition` widgets as part of route
/// transition machinery, which a bare `find.byType` would also match.
Finder _within(Type ancestor, Type widgetType) {
  return find.descendant(
    of: find.byType(ancestor),
    matching: find.byType(widgetType),
  );
}

void main() {
  group('AppSkeleton — delayed show (design/05 §5 Rule 1)', () {
    testWidgets('renders nothing on the first frame', (tester) async {
      await tester.pumpWidget(_wrap(const TextLineSkeleton()));

      expect(_within(TextLineSkeleton, ColoredBox), findsNothing);
    });

    testWidgets('still renders nothing just before the ~200 ms delay elapses', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const TextLineSkeleton()));
      await tester.pump(const Duration(milliseconds: 150));

      expect(_within(TextLineSkeleton, ColoredBox), findsNothing);
    });

    testWidgets('appears once the delay elapses', (tester) async {
      await tester.pumpWidget(_wrap(const TextLineSkeleton()));
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(_within(TextLineSkeleton, ColoredBox), findsWidgets);
    });
  });

  group('AppSkeleton — reduced motion (design/05 §9, §10)', () {
    testWidgets(
      'honours MediaQuery.disableAnimations with a static fallback — no shimmer',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const TextLineSkeleton(), disableAnimations: true),
        );
        await tester.pump(AppMotion.short);
        await tester.pump();

        expect(_within(TextLineSkeleton, FadeTransition), findsNothing);
        expect(_within(TextLineSkeleton, ColoredBox), findsWidgets);
      },
    );

    testWidgets(
      'shimmer runs (FadeTransition present) when motion is not reduced',
      (tester) async {
        await tester.pumpWidget(_wrap(const TextLineSkeleton()));
        await tester.pump(AppMotion.short);
        await tester.pump();

        expect(_within(TextLineSkeleton, FadeTransition), findsWidgets);
      },
    );

    testWidgets(
      'switching MediaQuery to disableAnimations turns an already-running shimmer off',
      (tester) async {
        await tester.pumpWidget(_wrap(const TextLineSkeleton()));
        await tester.pump(AppMotion.short);
        await tester.pump();
        expect(_within(TextLineSkeleton, FadeTransition), findsWidgets);

        await tester.pumpWidget(
          _wrap(const TextLineSkeleton(), disableAnimations: true),
        );
        await tester.pump();

        expect(_within(TextLineSkeleton, FadeTransition), findsNothing);
      },
    );
  });

  group(
    'AppSkeleton — shimmer cycle (design/02 §9 AppMotion.skeletonCycle)',
    () {
      testWidgets(
        'the shimmer opacity oscillates across one AppMotion.skeletonCycle',
        (tester) async {
          await tester.pumpWidget(_wrap(const TextLineSkeleton()));
          await tester.pump(AppMotion.short);
          await tester.pump();

          final fadeTransitionFinder = _within(
            TextLineSkeleton,
            FadeTransition,
          );
          double opacityOf() => tester
              .widget<FadeTransition>(fadeTransitionFinder.first)
              .opacity
              .value;

          var minOpacity = 1.0;
          var maxOpacity = 0.0;
          const steps = 8;
          for (var i = 0; i < steps; i++) {
            final value = opacityOf();
            if (value < minOpacity) minOpacity = value;
            if (value > maxOpacity) maxOpacity = value;
            await tester.pump(AppMotion.skeletonCycle ~/ steps);
          }

          // Sampled across a full cycle, the pulse must have visited both near
          // the base tone and near the highlight tone.
          expect(minOpacity, lessThan(0.3));
          expect(maxOpacity, greaterThan(0.7));
        },
      );

      testWidgets('is accessible as a single "Loading" semantics region', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap(const TextLineSkeleton()));
        await tester.pump(AppMotion.short);
        await tester.pump();

        expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      });
    },
  );

  group('AppSkeleton — the four variants exist and render (design/03 §25)', () {
    testWidgets('TextLineSkeleton renders with a custom widthFactor', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const TextLineSkeleton(widthFactor: 0.5)));
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(_within(TextLineSkeleton, FractionallySizedBox), findsWidgets);
    });

    testWidgets('ListTileSkeleton renders an avatar bone and two line bones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(width: 300, child: ListTileSkeleton())),
      );
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(ListTileSkeleton), findsOneWidget);
      expect(_within(ListTileSkeleton, ColoredBox), findsWidgets);
    });

    testWidgets('DetailSkeleton renders an image bone and several line bones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(width: 300, child: DetailSkeleton())),
      );
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(_within(DetailSkeleton, AspectRatio), findsOneWidget);
    });

    testWidgets('ProductCardSkeleton renders an image bone and line bones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(width: 200, child: ProductCardSkeleton())),
      );
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(_within(ProductCardSkeleton, AspectRatio), findsOneWidget);
    });
  });
}

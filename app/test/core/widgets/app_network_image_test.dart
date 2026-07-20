import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_motion.dart';
import 'package:footverse/core/theme/app_radius.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_network_image.dart';

/// Scopes a finder to descendants of [AppNetworkImage] — `MaterialApp`
/// itself renders its own `ColoredBox` internally, which a bare
/// `find.byType` would also match (the lesson from Task 03's skeleton tests).
Finder _within(Type widgetType) {
  return find.descendant(
    of: find.byType(AppNetworkImage),
    matching: find.byType(widgetType),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group(
    'AppNetworkImage — null and empty URL never throw (design/02 §2.5)',
    () {
      testWidgets('a null url renders the standard placeholder, no exception', (
        tester,
      ) async {
        await _pump(tester, const AppNetworkImage(url: null, width: 80));

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets(
        'an empty url renders the standard placeholder, no exception',
        (tester) async {
          await _pump(tester, const AppNetworkImage(url: '', width: 80));

          expect(tester.takeException(), isNull);
          expect(
            find.byIcon(Icons.image_not_supported_outlined),
            findsOneWidget,
          );
          expect(find.byType(CachedNetworkImage), findsNothing);
        },
      );

      testWidgets('the placeholder occupies exactly the requested size', (
        tester,
      ) async {
        await _pump(
          tester,
          const AppNetworkImage(url: null, width: 64, height: 96),
        );

        expect(
          tester.getSize(find.byType(AppNetworkImage)),
          const Size(64, 96),
        );
      });
    },
  );

  group('AppNetworkImage — non-empty URL delegates to CachedNetworkImage', () {
    testWidgets(
      'a well-formed url is passed through unmodified, no exception at build time',
      (tester) async {
        await _pump(
          tester,
          const AppNetworkImage(url: 'https://example.com/shoe.png', width: 80),
        );

        expect(tester.takeException(), isNull);
        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(image.imageUrl, 'https://example.com/shoe.png');
      },
    );

    testWidgets(
      'an invalid (non-URL) string is passed through without throwing',
      (tester) async {
        await _pump(
          tester,
          const AppNetworkImage(url: 'not a valid url', width: 80),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      },
    );

    testWidgets('width, height, and BoxFit.cover are wired through exactly', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppNetworkImage(
          url: 'https://example.com/shoe.png',
          width: 80,
          height: 120,
        ),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.width, 80);
      expect(image.height, 120);
      expect(image.fit, BoxFit.cover);
    });
  });

  group('AppNetworkImage — placeholder is a skeleton, never a spinner', () {
    testWidgets('the wired placeholder builder renders no spinner of any kind', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppNetworkImage(
          url: 'https://example.com/shoe.png',
          width: 80,
          height: 80,
        ),
      );
      final cachedImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      final context = tester.element(find.byType(CachedNetworkImage));
      final placeholderWidget = cachedImage.placeholder!(
        context,
        cachedImage.imageUrl,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: placeholderWidget),
        ),
      );
      await tester.pump(AppMotion.short);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The skeleton bone renders as a base ColoredBox (surfaceContainerHighest);
      // its presence, at the requested size, is the skeleton treatment.
      expect(find.byType(ColoredBox), findsWidgets);
      expect(tester.getSize(find.byType(SizedBox).first), const Size(80, 80));
    });
  });

  group(
    'AppNetworkImage — error fallback (design/02 §2.5, design/03 §25-27 spirit)',
    () {
      late CachedNetworkImage cachedImage;
      late BuildContext context;
      late Widget errorWidget;

      Future<void> buildErrorWidget(
        WidgetTester tester, {
        double width = 80,
        double height = 80,
      }) async {
        await _pump(
          tester,
          AppNetworkImage(
            url: 'https://example.com/shoe.png',
            width: width,
            height: height,
          ),
        );
        cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        context = tester.element(find.byType(CachedNetworkImage));
        errorWidget = cachedImage.errorWidget!(
          context,
          cachedImage.imageUrl,
          Exception('fetch failed'),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: errorWidget),
          ),
        );
        await tester.pump();
      }

      testWidgets('renders the standard placeholder icon, not the exception', (
        tester,
      ) async {
        await buildErrorWidget(tester);

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('fetch failed'), findsNothing);
      });

      testWidgets('never shows a retry button', (tester) async {
        await buildErrorWidget(tester);

        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        expect(find.text('Retry'), findsNothing);
      });

      testWidgets('never shows a spinner', (tester) async {
        await buildErrorWidget(tester);

        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets(
        'occupies exactly the same size that was requested — no layout shift',
        (tester) async {
          await buildErrorWidget(tester, width: 64, height: 96);

          expect(
            tester.getSize(find.byType(SizedBox).first),
            const Size(64, 96),
          );
        },
      );

      testWidgets(
        'the placeholder icon uses the outline role, never a red error colour',
        (tester) async {
          await buildErrorWidget(tester);

          final icon = tester.widget<Icon>(
            find.byIcon(Icons.image_not_supported_outlined),
          );
          final theme = AppTheme.light();
          expect(icon.color, theme.colorScheme.outline);
          expect(icon.color, isNot(Colors.red));
        },
      );
    },
  );

  group('AppNetworkImage — Imagery Contract (design/02 §2.5)', () {
    testWidgets('defaults to a 1:1 square when height is omitted', (
      tester,
    ) async {
      await _pump(tester, const AppNetworkImage(url: null, width: 88));

      final size = tester.getSize(find.byType(AppNetworkImage));
      expect(size.width, 88);
      expect(size.height, 88);
    });

    testWidgets('an explicit height overrides the 1:1 default', (tester) async {
      await _pump(
        tester,
        const AppNetworkImage(url: null, width: 88, height: 60),
      );

      final size = tester.getSize(find.byType(AppNetworkImage));
      expect(size.width, 88);
      expect(size.height, 60);
    });

    testWidgets('the corner radius is exactly AppRadius.sm — no other value', (
      tester,
    ) async {
      await _pump(tester, const AppNetworkImage(url: null, width: 80));

      final clipRRect = tester.widget<ClipRRect>(_within(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(AppRadius.sm));
    });

    testWidgets(
      'the background is surfaceContainerHighest — never a hardcoded colour',
      (tester) async {
        await _pump(tester, const AppNetworkImage(url: null, width: 80));

        final coloredBox = tester.widget<ColoredBox>(_within(ColoredBox));
        final theme = AppTheme.light();
        expect(coloredBox.color, theme.colorScheme.surfaceContainerHighest);
      },
    );
  });
}

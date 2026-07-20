import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_motion.dart';

void main() {
  group('AppMotion (design/02 §9)', () {
    test('durations match the ratified spec exactly', () {
      expect(AppMotion.instant, const Duration(milliseconds: 100));
      expect(AppMotion.short, const Duration(milliseconds: 200));
      expect(AppMotion.medium, const Duration(milliseconds: 300));
      expect(AppMotion.long, const Duration(milliseconds: 500));
      expect(AppMotion.skeletonCycle, const Duration(milliseconds: 1200));
    });

    test('nothing exceeds 500 ms among the transition durations', () {
      final transitionDurations = <Duration>[
        AppMotion.instant,
        AppMotion.short,
        AppMotion.medium,
        AppMotion.long,
      ];

      for (final duration in transitionDurations) {
        expect(duration.inMilliseconds, lessThanOrEqualTo(500));
      }
    });

    test('no two durations collide', () {
      final values = <Duration>{
        AppMotion.instant,
        AppMotion.short,
        AppMotion.medium,
        AppMotion.long,
        AppMotion.skeletonCycle,
      };

      expect(values.length, 5);
    });

    test('curves match the ratified spec exactly', () {
      expect(AppMotion.standard, Curves.easeInOutCubicEmphasized);
      expect(AppMotion.enter, Curves.easeOutCubic);
      expect(AppMotion.exit, Curves.easeInCubic);
    });
  });
}

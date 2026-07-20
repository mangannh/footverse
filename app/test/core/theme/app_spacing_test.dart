import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_spacing.dart';

void main() {
  group('AppSpacing (design/02 §3.2)', () {
    test('scale values match the ratified spec exactly', () {
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.xs, 8);
      expect(AppSpacing.sm, 12);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.lg, 24);
      expect(AppSpacing.xl, 32);
      expect(AppSpacing.xxl, 48);
    });

    test('no two steps collide', () {
      final values = <double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];

      expect(values.toSet().length, values.length);
    });

    test('every step is on the 4 dp base unit — no retired value (2, 6)', () {
      final values = <double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];

      for (final value in values) {
        expect(value % 4, 0, reason: '$value is off the 4 dp scale');
        expect(value, isNot(2));
        expect(value, isNot(6));
      }
    });

    test('scale is strictly increasing', () {
      final values = <double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];

      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });
  });
}

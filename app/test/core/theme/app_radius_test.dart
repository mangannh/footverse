import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_radius.dart';

void main() {
  group('AppRadius (design/02 §5)', () {
    test('exactly two values, matching the ratified spec', () {
      expect(AppRadius.sm, 8);
      expect(AppRadius.lg, 16);
    });

    test('the two radii do not collide', () {
      expect(AppRadius.sm, isNot(AppRadius.lg));
    });
  });
}

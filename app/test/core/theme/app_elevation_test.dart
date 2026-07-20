import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_elevation.dart';

void main() {
  group('AppElevation (design/02 §6)', () {
    test('four levels match the ratified spec exactly', () {
      expect(AppElevation.none, 0);
      expect(AppElevation.raised, 1);
      expect(AppElevation.sticky, 3);
      expect(AppElevation.overlay, 6);
    });

    test('no two levels collide', () {
      final values = <double>[
        AppElevation.none,
        AppElevation.raised,
        AppElevation.sticky,
        AppElevation.overlay,
      ];

      expect(values.toSet().length, values.length);
    });

    test('levels are strictly increasing', () {
      final values = <double>[
        AppElevation.none,
        AppElevation.raised,
        AppElevation.sticky,
        AppElevation.overlay,
      ];

      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });
  });
}

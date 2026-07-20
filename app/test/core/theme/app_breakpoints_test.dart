import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_breakpoints.dart';

void main() {
  group('AppBreakpoints (design/02 §11)', () {
    test('thresholds match the ratified spec exactly', () {
      expect(AppBreakpoints.compact, 0);
      expect(AppBreakpoints.medium, 600);
      expect(AppBreakpoints.expanded, 840);
    });

    test('thresholds are strictly increasing', () {
      expect(AppBreakpoints.medium, greaterThan(AppBreakpoints.compact));
      expect(AppBreakpoints.expanded, greaterThan(AppBreakpoints.medium));
    });
  });
}

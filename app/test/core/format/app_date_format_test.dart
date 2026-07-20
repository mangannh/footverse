import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/format/app_date_format.dart';
import 'package:intl/intl.dart';

void main() {
  group('AppDateFormat.format (design/02 §16.1, design/03 §14 mock-up)', () {
    test('matches the ratified mock-up exactly: 19 Jul 2026', () {
      expect(AppDateFormat.format(DateTime(2026, 7, 19)), '19 Jul 2026');
    });

    test('a single-digit day is not zero-padded', () {
      expect(AppDateFormat.format(DateTime(2026, 1, 5)), '5 Jan 2026');
    });

    test('every month renders its standard English abbreviation', () {
      const expected = <int, String>{
        1: 'Jan',
        2: 'Feb',
        3: 'Mar',
        4: 'Apr',
        5: 'May',
        6: 'Jun',
        7: 'Jul',
        8: 'Aug',
        9: 'Sep',
        10: 'Oct',
        11: 'Nov',
        12: 'Dec',
      };

      for (final entry in expected.entries) {
        final formatted = AppDateFormat.format(DateTime(2026, entry.key, 1));
        expect(formatted, '1 ${entry.value} 2026');
      }
    });

    test('handles a leap-year day (29 Feb)', () {
      expect(AppDateFormat.format(DateTime(2024, 2, 29)), '29 Feb 2024');
    });

    test('handles the year boundary (31 Dec / 1 Jan)', () {
      expect(AppDateFormat.format(DateTime(2025, 12, 31)), '31 Dec 2025');
      expect(AppDateFormat.format(DateTime(2026, 1, 1)), '1 Jan 2026');
    });

    test(
      'formats a DateTime carrying a time-of-day using only its date fields',
      () {
        expect(
          AppDateFormat.format(DateTime(2026, 7, 19, 23, 59, 59)),
          '19 Jul 2026',
        );
      },
    );

    group('locale is fixed, never the device/default locale', () {
      final originalDefaultLocale = Intl.defaultLocale;

      tearDown(() {
        Intl.defaultLocale = originalDefaultLocale;
      });

      test(
        'output is unchanged when Intl.defaultLocale is switched to Vietnamese',
        () {
          Intl.defaultLocale = 'vi_VN';

          expect(AppDateFormat.format(DateTime(2026, 7, 19)), '19 Jul 2026');
        },
      );

      test(
        'output is unchanged when Intl.defaultLocale is switched to French',
        () {
          Intl.defaultLocale = 'fr_FR';

          expect(AppDateFormat.format(DateTime(2026, 7, 19)), '19 Jul 2026');
        },
      );
    });
  });
}

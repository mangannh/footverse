import 'package:intl/intl.dart';

/// The single shared date formatter for FootVerse (design/02 §16.1).
///
/// Every date in the application renders through [format] — no screen or
/// widget formats a date independently. Locale is fixed to match the
/// English interface language, never the device locale, so the same date
/// reads identically on every phone.
class AppDateFormat {
  const AppDateFormat._();

  static const String _locale = 'en_US';
  static const String _pattern = 'd MMM yyyy';

  /// Formats [date] as `19 Jul 2026` (design/03 §14, order card mock-up).
  ///
  /// Renders [date]'s own calendar fields as given — no timezone conversion
  /// is applied, matching the behaviour of every formatter it replaces.
  static String format(DateTime date) {
    return DateFormat(_pattern, _locale).format(date);
  }
}

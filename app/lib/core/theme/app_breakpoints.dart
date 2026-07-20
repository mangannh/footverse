/// The FootVerse responsive breakpoints (design/02 §11).
///
/// Mobile-first: [compact] is the design target: larger sizes are supported,
/// not designed for. Widths are inclusive lower bounds for the named tier.
class AppBreakpoints {
  const AppBreakpoints._();

  /// 0 dp — phones. The design target.
  static const double compact = 0;

  /// 600 dp — product grid moves to 3 columns; content max-width 600 dp, centred.
  static const double medium = 600;

  /// 840 dp — product grid moves to 4 columns; content max-width 840 dp, centred.
  static const double expanded = 840;
}

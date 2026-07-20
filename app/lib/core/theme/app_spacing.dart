/// The FootVerse spacing scale (design/02 §3).
///
/// An 8 dp layout rhythm with a 4 dp intra-component base unit. Every gap and
/// padding value in the application must come from this scale — no arithmetic
/// on a token, no value off the scale (design/02 §3.3).
class AppSpacing {
  const AppSpacing._();

  /// 4 dp — a label directly under its value.
  static const double xxs = 4;

  /// 8 dp — tightly related elements.
  static const double xs = 8;

  /// 12 dp — internal component padding.
  static const double sm = 12;

  /// 16 dp — standard screen padding; gap between list items.
  static const double md = 16;

  /// 24 dp — between content groups.
  static const double lg = 24;

  /// 32 dp — between major sections.
  static const double xl = 32;

  /// 48 dp — large voids, empty-state breathing room.
  static const double xxl = 48;
}

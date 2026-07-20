/// The FootVerse corner radius scale (design/02 §5).
///
/// Exactly two values exist. A third radius anywhere in the application is a
/// review failure.
class AppRadius {
  const AppRadius._();

  /// 8 dp — images, cards, inputs, chips, buttons.
  static const double sm = 8;

  /// 16 dp — bottom sheets, dialogs.
  static const double lg = 16;
}

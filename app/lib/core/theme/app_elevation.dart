/// The FootVerse elevation scale (design/02 §6).
///
/// Elevation is scarce — whitespace and surface tiers are the default
/// separators; these four levels are reserved for surfaces that genuinely
/// float above content.
class AppElevation {
  const AppElevation._();

  /// 0 — default for all content, including cards.
  static const double none = 0;

  /// 1 — cards, only where a boundary is genuinely needed.
  static const double raised = 1;

  /// 3 — sticky bottom bars, app bar when scrolled under.
  static const double sticky = 3;

  /// 6 — dialogs, bottom sheets, menus.
  static const double overlay = 6;
}

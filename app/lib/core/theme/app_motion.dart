import 'package:flutter/animation.dart';

/// The FootVerse motion tokens (design/02 §9).
///
/// Values only — when and what to animate is policy, defined in
/// `docs/design/05-animation-guidelines.md`. Nothing in the application may
/// exceed [long]; a duration a user must wait through is a defect.
class AppMotion {
  const AppMotion._();

  /// 100 ms — ripples, checkbox, toggle.
  static const Duration instant = Duration(milliseconds: 100);

  /// 200 ms — fades, small expansions, chip selection.
  static const Duration short = Duration(milliseconds: 200);

  /// 300 ms — page transitions, sheet entry, list changes.
  static const Duration medium = Duration(milliseconds: 300);

  /// 500 ms — full-screen transitions only. Rare.
  static const Duration long = Duration(milliseconds: 500);

  /// 1200 ms — skeleton shimmer cycle.
  static const Duration skeletonCycle = Duration(milliseconds: 1200);

  /// Default curve for everything.
  static const Curve standard = Curves.easeInOutCubicEmphasized;

  /// Curve for elements entering.
  static const Curve enter = Curves.easeOutCubic;

  /// Curve for elements leaving.
  static const Curve exit = Curves.easeInCubic;
}

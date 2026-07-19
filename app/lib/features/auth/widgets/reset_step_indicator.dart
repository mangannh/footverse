import 'package:flutter/material.dart';

/// The three-step progress indication shown on every password-reset screen
/// (sprint-13-plan Task 07 UX requirements), so the user always knows where
/// they are in the flow. Reused by all three steps — extracted here rather
/// than duplicated (flutter-guidelines §Component Extraction).
class ResetStepIndicator extends StatelessWidget {
  const ResetStepIndicator({required this.step, super.key});

  /// The current step, 1-based, out of [totalSteps].
  final int step;

  static const int totalSteps = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(value: step / totalSteps),
        const SizedBox(height: 4),
        Text(
          'Step $step of $totalSteps',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

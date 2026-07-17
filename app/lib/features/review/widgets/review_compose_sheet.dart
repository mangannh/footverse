import 'package:flutter/material.dart';

/// The validated result of the compose sheet: a rating (1–5) and an optional
/// comment (already trimmed; null when blank so the request omits it).
class ReviewDraft {
  const ReviewDraft({required this.rating, this.comment});

  final int rating;
  final String? comment;
}

/// The bottom sheet that composes a review — shared by create and edit
/// (sprint-9-plan item 05). It collects a 1–5 [rating] and an optional
/// [comment] (max 500 chars), mirroring the frozen constraints exactly
/// (validation-spec §11) and inventing no client rule: the star selector cannot
/// express a rating outside 1–5, the field caps the comment length, and Submit is
/// disabled until a rating is chosen. The server remains authoritative — this
/// sheet only gathers input and pops a [ReviewDraft]; it issues no request.
class ReviewComposeSheet extends StatefulWidget {
  const ReviewComposeSheet({
    super.key,
    this.initialRating,
    this.initialComment,
  });

  /// The existing rating when editing; null when creating.
  final int? initialRating;

  /// The existing comment when editing; null when creating or none.
  final String? initialComment;

  @override
  State<ReviewComposeSheet> createState() => _ReviewComposeSheetState();
}

class _ReviewComposeSheetState extends State<ReviewComposeSheet> {
  /// The max comment length (validation-spec §11: `@Size(max=500)`).
  static const int _maxCommentLength = 500;

  /// The rating bounds (validation-spec §11: `@Min(1)`, `@Max(5)`).
  static const int _minRating = 1;
  static const int _maxRating = 5;

  late int _rating;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 0;
    _commentController = TextEditingController(
      text: widget.initialComment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.initialRating != null;

  bool get _canSubmit => _rating >= _minRating && _rating <= _maxRating;

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    final raw = _commentController.text.trim();
    Navigator.of(
      context,
    ).pop(ReviewDraft(rating: _rating, comment: raw.isEmpty ? null : raw));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _isEditing ? 'Edit your review' : 'Write a review',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text('Rating', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          _RatingSelector(
            rating: _rating,
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLength: _maxCommentLength,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: Text(_isEditing ? 'Save' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 1–5 star selector. Tapping a star sets the rating to its position; the
/// selector cannot express a value outside the frozen 1–5 range.
class _RatingSelector extends StatelessWidget {
  const _RatingSelector({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        for (int value = 1; value <= 5; value++)
          IconButton(
            onPressed: () => onChanged(value),
            icon: Icon(
              value <= rating ? Icons.star : Icons.star_border,
              color: colorScheme.primary,
            ),
            tooltip: '$value',
          ),
      ],
    );
  }
}

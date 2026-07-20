import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A selectable brand/category option inside the filter sheet
/// (design/03 §7). Wraps [FilterChip]; selection is always conveyed with
/// **fill and a check icon**, never fill alone (design/02 §2.4).
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;

  /// `null` disables selection.
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

/// A currently-applied filter, with `×` to remove it (design/03 §7). Wraps
/// [InputChip]; always renders the same fill-and-check treatment as a
/// selected [CategoryChip] — an active filter chip is, by definition, an
/// applied (selected) filter.
class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      selected: true,
      showCheckmark: true,
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close),
      deleteButtonTooltipMessage: 'Remove $label filter',
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

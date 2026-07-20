import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

/// The one search component, used in every placement (design/03 §6).
///
/// Debounces at [_debounceDuration] (400 ms) while typing — the baseline
/// searched only on submit, which hid the feature from anyone who never
/// pressed enter. **No autocomplete or suggestion surface**: no endpoint
/// supports them.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onSearch,
    this.initialValue,
    this.onClear,
  });

  /// Called with the current text after the debounce settles, and
  /// immediately on submit or clear.
  final ValueChanged<String> onSearch;

  final String? initialValue;

  /// Called when the clear (`×`) action is used, in addition to [onSearch]
  /// being called with an empty string.
  final VoidCallback? onClear;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  Timer? _debounce;
  bool _hasText = false;

  static const Duration _debounceDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      widget.onSearch(_controller.text);
    });
  }

  void _handleSubmitted(String value) {
    _debounce?.cancel();
    widget.onSearch(value);
    FocusScope.of(context).unfocus();
  }

  void _handleClear() {
    // clear() notifies the controller's listener, which schedules a fresh
    // debounce — cancel it after, or a duplicate onSearch('') fires 400 ms
    // later.
    _controller.clear();
    _debounce?.cancel();
    widget.onSearch('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: _handleSubmitted,
      decoration: InputDecoration(
        labelText: 'Search products',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _hasText
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
                onPressed: _handleClear,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        isDense: true,
      ),
    );
  }
}

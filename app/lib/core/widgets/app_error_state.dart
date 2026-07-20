import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The shared error state for a data-backed surface that failed to load
/// (design/03 §27) — the single replacement for the nine near-identical
/// `_ErrorView` classes in the baseline.
///
/// Fully reusable: it renders [message] and invokes [onRetry] and nothing
/// else. It never reloads data itself and knows nothing about any provider
/// or repository — the caller supplies the provider's own `retry()`.
class AppErrorState extends StatefulWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// The server's message, exactly as delivered by `AppException`. Never a
  /// raw error code, HTTP status, exception type, or stack trace.
  final String message;

  /// Re-invoked when the customer taps retry.
  final Future<void> Function() onRetry;

  @override
  State<AppErrorState> createState() => _AppErrorStateState();
}

class _AppErrorStateState extends State<AppErrorState> {
  bool _retrying = false;

  static const double _iconSize = 48;
  static const double _spinnerSize = 20;

  Future<void> _handleRetry() async {
    if (_retrying) {
      return;
    }
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } catch (_) {
      // The caller's retry() already owns its own error state (the
      // established provider pattern); this component only needs to
      // guarantee the button re-enables so the customer can try again.
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: _iconSize,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                widget.message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _retrying ? null : _handleRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.xxl),
                ),
                child: _retrying
                    ? const SizedBox(
                        height: _spinnerSize,
                        width: _spinnerSize,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

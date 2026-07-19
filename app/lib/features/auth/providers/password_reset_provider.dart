import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../models/forgot_password_request.dart';
import '../models/reset_password_request.dart';
import '../models/verify_reset_otp_request.dart';
import '../repositories/auth_repository.dart';

/// Lifecycle of the currently in-flight password-reset step.
enum PasswordResetStatus { idle, loading, success, error }

/// Owns the three-step password-reset state machine — request the emailed
/// code, verify it, then set a new password — for the reset screens
/// (flutter-guidelines §State Management; sprint-13-plan Task 06).
///
/// It is **screen-scoped**: created once by the first screen of the flow and
/// passed down the two nested routes (Task 07), because the opaque
/// [resetToken] returned by [verifyOtp] must survive the navigation to the
/// final step. It is never registered app-root and never read by another
/// feature.
///
/// Each of [requestOtp], [verifyOtp], and [resetPassword] is **single-flight**
/// (a call while [status] is already [PasswordResetStatus.loading] is
/// ignored), moves through [PasswordResetStatus.loading] to either
/// [PasswordResetStatus.success] or [PasswordResetStatus.error], and
/// **rethrows** the repository's [AppException] unchanged so the screen
/// renders the enveloped message (flutter-guidelines §Error Handling). A
/// failed step leaves the flow exactly where it was — in particular a failed
/// [resetPassword] keeps the already-captured [resetToken] — so the caller can
/// retry without repeating an earlier step. This provider never touches the
/// app-root `AuthProvider`, never stores a token anywhere, and never signs the
/// user in — a completed reset leaves the caller signed out.
class PasswordResetProvider extends ChangeNotifier {
  PasswordResetProvider(this._repository);

  final AuthRepository _repository;

  PasswordResetStatus _status = PasswordResetStatus.idle;
  AppException? _error;
  String? _resetToken;
  bool _disposed = false;

  /// The current step's lifecycle status.
  PasswordResetStatus get status => _status;

  /// The current step's error, set only while [status] is
  /// [PasswordResetStatus.error].
  AppException? get error => _error;

  /// The opaque reset token issued by [verifyOtp], held **in memory only**
  /// for the lifetime of this provider. Null until the code has been
  /// verified; never written to any storage.
  String? get resetToken => _resetToken;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Step 1 — `POST /auth/forgot-password`. Always succeeds from the caller's
  /// perspective; the server never reveals whether the email is registered.
  Future<void> requestOtp(ForgotPasswordRequest request) =>
      _run(() => _repository.forgotPassword(request));

  /// Step 2 — `POST /auth/verify-reset-otp`. On success stores the returned
  /// opaque token in memory for [resetPassword].
  Future<void> verifyOtp(VerifyResetOtpRequest request) => _run(() async {
    final response = await _repository.verifyResetOtp(request);
    _resetToken = response.resetToken;
  });

  /// Step 3 — `POST /auth/reset-password`, using the token captured by a
  /// prior successful [verifyOtp]. Never signs the caller in.
  Future<void> resetPassword(String newPassword) {
    final token = _resetToken;
    if (token == null) {
      throw StateError('resetPassword called before verifyOtp succeeded');
    }
    return _run(
      () => _repository.resetPassword(
        ResetPasswordRequest(resetToken: token, newPassword: newPassword),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_status == PasswordResetStatus.loading) {
      return;
    }
    _status = PasswordResetStatus.loading;
    _error = null;
    _safeNotify();
    try {
      await action();
      _status = PasswordResetStatus.success;
    } on AppException catch (exception) {
      _error = exception;
      _status = PasswordResetStatus.error;
      _safeNotify();
      rethrow;
    }
    _safeNotify();
  }

  // Guards against notifying after disposal: a step that completes once the
  // screen (and this provider) is gone must not call notifyListeners.
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

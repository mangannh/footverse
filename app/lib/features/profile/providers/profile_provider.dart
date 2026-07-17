import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/models/user_response.dart';
import '../models/change_email_request.dart';
import '../models/change_password_request.dart';
import '../models/update_profile_request.dart';
import '../repositories/profile_repository.dart';

/// Lifecycle of the profile load, which drives the full-screen states.
enum ProfileStatus { loading, ready, error }

/// Owns the caller's profile state for the profile screen (flutter-guidelines
/// §State Management; sprint-9-plan item 06).
///
/// It is **screen-scoped** — created by the profile screen and disposed with it,
/// so it needs no sign-out reset and no other feature reads it. It is the
/// authoritative profile view: it re-fetches `GET /users/me` on mount (Design
/// Decision 1), never the app-root [AuthProvider]'s cached user, and it never
/// mutates that cached user after an update (Design Decision 2) — the two
/// providers stay independent. Every call is self-scoped by the bearer; no
/// endpoint receives a user id (Design Decision 3).
///
/// A load failure moves to [ProfileStatus.error] with a retry affordance. The
/// profile update is **single-flight** (the Sprint 7/8 mutation-guard idiom): it
/// replaces the held [UserResponse] with the **server's** response on success
/// (never a per-field mutation or a follow-up `GET`), and **rethrows** the
/// [AppException] on failure (e.g. `409 USER_PHONE_DUPLICATED`) so the screen
/// renders the enveloped message, leaving the held profile unchanged. The client
/// re-implements no rule — uniqueness, `enabled`, `role`, and `email` are all
/// server-authoritative (Design Decision 4).
///
/// The two re-authenticated credential writes (sprint-9-plan item 07) share this
/// same single-flight guard: [changePassword] returns void (no profile state to
/// replace) and [changeEmail] replaces the held [UserResponse] with the server's
/// response. Both **rethrow** the [AppException] on a server rejection
/// (`400 USER_CURRENT_PASSWORD_INVALID`, `409 USER_EMAIL_DUPLICATED`) without
/// touching state, and neither adds token logic — the email-change token
/// consequence is handled transparently by the existing `AuthInterceptor`.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repository);

  final ProfileRepository _repository;

  ProfileStatus _status = ProfileStatus.loading;
  UserResponse? _user;
  AppException? _error;
  bool _updating = false;
  bool _disposed = false;

  /// The load lifecycle status.
  ProfileStatus get status => _status;

  /// The loaded profile, set once [status] is [ProfileStatus.ready].
  UserResponse? get user => _user;

  /// The load error, set only while [status] is [ProfileStatus.error].
  AppException? get error => _error;

  /// True while a profile update is in flight; the Save action disables itself so
  /// updates stay single-flight.
  bool get isUpdating => _updating;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Loads the caller's profile (`GET /users/me`), called once on screen mount.
  Future<void> load() => _load();

  /// Retries the load after a [ProfileStatus.error].
  Future<void> retry() => _load();

  /// Updates the caller's editable profile fields (`PUT /users/me`) and replaces
  /// the held profile with the server's response on success (Design Decision 1/4).
  ///
  /// Single-flight: a call while one is already in flight is ignored. Rethrows
  /// [AppException] on failure without touching the held profile, so the screen
  /// renders the enveloped message (flutter-guidelines §Error Handling).
  Future<void> updateProfile(UpdateProfileRequest request) async {
    if (_updating) {
      return;
    }
    _updating = true;
    _safeNotify();
    try {
      _user = await _repository.updateProfile(request);
    } finally {
      _updating = false;
      _safeNotify();
    }
  }

  /// Changes the caller's password (`PATCH /users/me/password`).
  ///
  /// Single-flight: a call while a write is already in flight is ignored. Returns
  /// void — there is no profile state to replace. Rethrows [AppException] on a
  /// server rejection (`400 USER_CURRENT_PASSWORD_INVALID`) without touching
  /// state, so the screen renders the enveloped message. It never persists,
  /// logs, or echoes the raw password (business-rules → Security).
  Future<void> changePassword(ChangePasswordRequest request) async {
    if (_updating) {
      return;
    }
    _updating = true;
    _safeNotify();
    try {
      await _repository.changePassword(request);
    } finally {
      _updating = false;
      _safeNotify();
    }
  }

  /// Changes the caller's email (`PATCH /users/me/email`) and replaces the held
  /// [UserResponse] with the server's response on success.
  ///
  /// Single-flight (see [changePassword]). Rethrows [AppException] on a server
  /// rejection (`400 USER_CURRENT_PASSWORD_INVALID`, `409 USER_EMAIL_DUPLICATED`)
  /// without touching state. Adds no token logic — the stale-token consequence is
  /// handled by the existing `AuthInterceptor` on the next authenticated call.
  Future<void> changeEmail(ChangeEmailRequest request) async {
    if (_updating) {
      return;
    }
    _updating = true;
    _safeNotify();
    try {
      _user = await _repository.changeEmail(request);
    } finally {
      _updating = false;
      _safeNotify();
    }
  }

  Future<void> _load() async {
    _status = ProfileStatus.loading;
    _error = null;
    _safeNotify();
    try {
      _user = await _repository.getMe();
      _status = ProfileStatus.ready;
    } on AppException catch (exception) {
      _error = exception;
      _status = ProfileStatus.error;
    }
    _safeNotify();
  }

  // Guards against notifying after disposal: a load or update that completes once
  // the screen (and this provider) is gone must not call notifyListeners.
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

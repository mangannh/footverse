import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import '../../product/models/review_response.dart';
import '../../profile/repositories/profile_repository.dart';
import '../models/create_review_request.dart';
import '../models/update_review_request.dart';
import '../repositories/review_repository.dart';

/// Owns the write-side review state for the product being viewed (sprint-9-plan
/// item 05): the signed-in caller's identity, the resolution of the caller's own
/// review, and the eligibility-gated create / owner edit / owner delete lifecycle.
///
/// It is **screen-scoped** — created by the product detail for one product — and
/// calls **only** [ReviewRepository] and [ProfileRepository] (Design Decision 3);
/// it never re-implements a business rule. The server stays the single authority
/// on eligibility, duplication, and ownership: the client's only ownership signal
/// is [ReviewResponse.userId] `== currentUser.id`, and any mismatched or stale
/// attempt surfaces as the enveloped `REVIEW_*` response, rendered by the widget.
///
/// The caller's identity comes from `GET /users/me` **only** — never a decoded
/// JWT, an email compare, or a name-match heuristic (Design Decision 3). Writes
/// are **single-flight** (the Sprint 7/8 mutation-guard idiom) and **rethrow** the
/// [AppException] so the screen renders the enveloped message via a `SnackBar`,
/// leaving state unchanged on failure. After a successful write it invokes
/// [_onReviewsChanged] — wired to the product detail's own public review reload
/// (`ProductDetailProvider.retryReviews`) at the composition root — so the
/// new / edited / removed review is reflected in the list without this provider
/// touching another feature's state.
class ReviewProvider extends ChangeNotifier {
  ReviewProvider({
    required ReviewRepository reviewRepository,
    required ProfileRepository profileRepository,
    required int productId,
    required VoidCallback onReviewsChanged,
  }) : _reviewRepository = reviewRepository,
       _profileRepository = profileRepository,
       _productId = productId,
       _onReviewsChanged = onReviewsChanged;

  final ReviewRepository _reviewRepository;
  final ProfileRepository _profileRepository;
  final int _productId;
  final VoidCallback _onReviewsChanged;

  int? _currentUserId;
  bool _identityLoaded = false;
  bool _hasWritten = false;
  ReviewResponse? _writeResult;
  bool _mutating = false;
  bool _disposed = false;

  /// The signed-in caller's id, sourced from `GET /users/me` only; null for a
  /// guest or before [loadCurrentUser] resolves.
  int? get currentUserId => _currentUserId;

  /// True once the identity load has completed (success or failure), so the
  /// affordance knows the ownership resolution is settled.
  bool get identityLoaded => _identityLoaded;

  /// True while a write is in flight; the affordance disables itself so writes
  /// stay single-flight.
  bool get isMutating => _mutating;

  /// The caller's own review for this product, or null when they have none.
  ///
  /// Before any write it is resolved from [reviews] purely by matching the
  /// server-provided [ReviewResponse.userId] against [currentUserId] (Design
  /// Decision 3 — the only ownership signal; never a JWT, email, name, avatar, or
  /// content heuristic). After a write the write's own result is authoritative
  /// (a create/edit yields the review, a delete yields null), so a just-written
  /// review is recognised even before the public list reload lands.
  ReviewResponse? ownReviewFrom(List<ReviewResponse> reviews) {
    if (_hasWritten) {
      return _writeResult;
    }
    final id = _currentUserId;
    if (id == null) {
      return null;
    }
    for (final review in reviews) {
      if (review.userId == id) {
        return review;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Loads the caller's id from `GET /users/me` (Design Decision 3). Called by the
  /// product detail only for an authenticated caller; a guest never loads it. A
  /// failed load degrades to an unresolved identity — the affordance falls back to
  /// the Write control and the server stays authoritative — so this best-effort
  /// read follows the codebase's load pattern (it is not a write) and does not
  /// surface an error.
  Future<void> loadCurrentUser() async {
    try {
      final user = await _profileRepository.getMe();
      _currentUserId = user.id;
    } on AppException {
      _currentUserId = null;
    } finally {
      _identityLoaded = true;
      _safeNotify();
    }
  }

  /// Creates the caller's review for this product (`POST /reviews`). Eligibility
  /// and the one-review-per-product rule are server-authoritative — an ineligible
  /// or duplicate attempt rethrows the enveloped `REVIEW_NOT_ELIGIBLE` /
  /// `REVIEW_DUPLICATED`.
  Future<void> submit(int rating, String? comment) => _mutate(() async {
    _writeResult = await _reviewRepository.createReview(
      CreateReviewRequest(
        productId: _productId,
        rating: rating,
        comment: comment,
      ),
    );
    _hasWritten = true;
  });

  /// Edits the caller's own [review] (`PUT /reviews/{id}`). Ownership is
  /// server-enforced — a stale or foreign id rethrows the enveloped
  /// `REVIEW_FORBIDDEN` / `REVIEW_NOT_FOUND`.
  Future<void> edit(ReviewResponse review, int rating, String? comment) =>
      _mutate(() async {
        _writeResult = await _reviewRepository.updateReview(
          review.id,
          UpdateReviewRequest(rating: rating, comment: comment),
        );
        _hasWritten = true;
      });

  /// Deletes the caller's own [review] (`DELETE /reviews/{id}`). Ownership is
  /// server-enforced as for [edit].
  Future<void> remove(ReviewResponse review) => _mutate(() async {
    await _reviewRepository.deleteReview(review.id);
    _writeResult = null;
    _hasWritten = true;
  });

  /// Runs a single-flight write: it no-ops if one is already in flight, triggers
  /// the public review reload after the write succeeds, and rethrows an
  /// [AppException] so the caller renders the enveloped message. On failure the
  /// held state is left unchanged (the write result is assigned only after the
  /// awaited call succeeds).
  Future<void> _mutate(Future<void> Function() action) async {
    if (_mutating) {
      return;
    }
    _mutating = true;
    _safeNotify();
    try {
      await action();
      _onReviewsChanged();
    } finally {
      _mutating = false;
      _safeNotify();
    }
  }

  // Guards against notifying after disposal: an in-flight identity load or write
  // that completes once this provider is gone must not call notifyListeners.
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

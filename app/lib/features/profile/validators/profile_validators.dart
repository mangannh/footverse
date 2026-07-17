/// Client-side field validators specific to the profile form.
///
/// It covers only the profile field the reused auth validators do not already
/// cover — the optional `avatarUrl` length (sprint-9-plan assumption 5). The
/// `fullName` (non-blank) and VN `phone` checks are reused from
/// `AuthValidators`, so they are not re-authored here. It mirrors the frozen
/// constraint of validation-spec §4 **exactly** (`@Size(max=512)`), so the
/// pre-submit check never rejects input the server would accept; the server
/// stays authoritative. validation-spec defines the constraint but no
/// user-facing string, so the message lives here as the single source.
class ProfileValidators {
  const ProfileValidators._();

  /// The max avatar URL length (validation-spec §4: `@Size(max=512)`).
  static const int _avatarUrlMaxLength = 512;

  static const String _avatarUrlTooLong = 'Avatar URL is too long (max 512)';

  /// `@Size(max=512)` — optional avatar URL; only its length is constrained. A
  /// blank value is accepted (the field is optional) and omitted by the request
  /// model.
  static String? avatarUrl(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return null;
    }
    if (input.length > _avatarUrlMaxLength) {
      return _avatarUrlTooLong;
    }
    return null;
  }
}

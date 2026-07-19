/// Client-side field validators for the auth forms.
///
/// They mirror the frozen constraints of validation-spec §1/§3 **exactly** — the
/// same required rules, length, and regular expressions — so the pre-submit
/// check never rejects input the server would accept (assumption 5). The server
/// stays authoritative; a `400 VALIDATION_ERROR` envelope is always rendered
/// faithfully by the screens. validation-spec defines the constraints but no
/// user-facing strings (the backend uses Bean Validation defaults), so the
/// messages below describe those constraints and live here as the single source
/// — never hardcoded inline in a widget.
class AuthValidators {
  const AuthValidators._();

  // Frozen patterns (validation-spec §1).
  // Email is kept intentionally lenient (local@domain, no whitespace) so it is
  // never stricter than the server's `@Email`.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+$');
  static final RegExp _passwordPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$');
  static final RegExp _phonePattern = RegExp(r'^0\d{9}$');
  static final RegExp _otpPattern = RegExp(r'^\d{6}$');

  static const int _passwordMinLength = 8;

  static const String _emailRequired = 'Email is required';
  static const String _emailInvalid = 'Enter a valid email address';
  static const String _passwordRequired = 'Password is required';
  static const String _passwordInvalid =
      'Password must be at least 8 characters and include a letter and a number';
  static const String _fullNameRequired = 'Full name is required';
  static const String _phoneRequired = 'Phone number is required';
  static const String _phoneInvalid =
      'Phone must be 10 digits and start with 0';
  static const String _otpRequired = 'Reset code is required';
  static const String _otpInvalid = 'Enter the 6-digit reset code';

  /// User-facing description of the [password] rule, for a screen to show
  /// proactively (e.g. as field helper text) before submission — the exact
  /// same wording [password] returns as its rejection message, so the rule is
  /// described in one place only (Sprint 13 Task 07).
  static const String passwordRuleHint = _passwordInvalid;

  /// `@NotBlank @Email` — required, valid email format.
  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return _emailRequired;
    }
    if (!_emailPattern.hasMatch(input)) {
      return _emailInvalid;
    }
    return null;
  }

  /// `@NotBlank @Size(min=8) @Pattern` — register password rules.
  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) {
      return _passwordRequired;
    }
    if (input.length < _passwordMinLength ||
        !_passwordPattern.hasMatch(input)) {
      return _passwordInvalid;
    }
    return null;
  }

  /// `@NotBlank` — login password is only required (the server matches the hash).
  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _passwordRequired;
    }
    return null;
  }

  /// `@NotBlank` — required full name.
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _fullNameRequired;
    }
    return null;
  }

  /// `@NotBlank @Pattern("^0\d{9}$")` — required VN phone.
  static String? phone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return _phoneRequired;
    }
    if (!_phonePattern.hasMatch(input)) {
      return _phoneInvalid;
    }
    return null;
  }

  /// `@NotBlank @Pattern("^\d{6}$")` — the emailed password-reset code
  /// (Sprint 13 Task 06).
  static String? validateOtp(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return _otpRequired;
    }
    if (!_otpPattern.hasMatch(input)) {
      return _otpInvalid;
    }
    return null;
  }
}

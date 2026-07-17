// Frozen login constraints (validation-spec §3): email is `@NotBlank @Email`,
// password is `@NotBlank` only (the server matches the stored hash). The email
// pattern is intentionally lenient (local@domain, no whitespace) so it is never
// stricter than the server's `@Email`; a pre-submit check never rejects input
// the server would accept. Messages live here as the single source, never inline.
const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+$/;
const EMAIL_REQUIRED = 'Email is required';
const EMAIL_INVALID = 'Enter a valid email address';
const PASSWORD_REQUIRED = 'Password is required';

/** Field validators for the login form (react-guidelines §Form Validation). */
export const authValidators = {
  /** `@NotBlank @Email` — required, valid email format. */
  email(value: string): string | undefined {
    const input = value.trim();
    if (input.length === 0) {
      return EMAIL_REQUIRED;
    }
    if (!EMAIL_PATTERN.test(input)) {
      return EMAIL_INVALID;
    }
    return undefined;
  },

  /** `@NotBlank` — login password is only required (the server matches the hash). */
  requiredPassword(value: string): string | undefined {
    if (value.length === 0) {
      return PASSWORD_REQUIRED;
    }
    return undefined;
  },
};

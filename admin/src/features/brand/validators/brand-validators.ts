// Frozen brand constraints (validation-spec §12): `name` is `@NotBlank`;
// `logoUrl` and `description` are optional with a `@Size(max=…)` length guard.
// A pre-submit check never rejects input the server would accept. Messages live
// here as the single source, never inline in a component.
const NAME_REQUIRED = 'Name is required';
const LOGO_URL_MAX_LENGTH = 512;
const LOGO_URL_TOO_LONG = `Logo URL must be at most ${LOGO_URL_MAX_LENGTH} characters`;
const DESCRIPTION_MAX_LENGTH = 2000;
const DESCRIPTION_TOO_LONG = `Description must be at most ${DESCRIPTION_MAX_LENGTH} characters`;

/** Field validators for the brand form (react-guidelines §Form Validation). */
export const brandValidators = {
  /** `@NotBlank` — required brand name. */
  name(value: string): string | undefined {
    if (value.trim().length === 0) {
      return NAME_REQUIRED;
    }
    return undefined;
  },

  /** `@Size(max=512)` — optional logo URL. */
  logoUrl(value: string): string | undefined {
    if (value.length > LOGO_URL_MAX_LENGTH) {
      return LOGO_URL_TOO_LONG;
    }
    return undefined;
  },

  /** `@Size(max=2000)` — optional description. */
  description(value: string): string | undefined {
    if (value.length > DESCRIPTION_MAX_LENGTH) {
      return DESCRIPTION_TOO_LONG;
    }
    return undefined;
  },
};

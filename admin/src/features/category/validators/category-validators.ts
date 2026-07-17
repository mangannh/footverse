// Frozen category constraints (validation-spec §12): `name` is `@NotBlank`;
// `description` is optional with a `@Size(max=2000)` length guard. A pre-submit
// check never rejects input the server would accept. Messages live here as the
// single source, never inline in a component.
const NAME_REQUIRED = 'Name is required';
const DESCRIPTION_MAX_LENGTH = 2000;
const DESCRIPTION_TOO_LONG = `Description must be at most ${DESCRIPTION_MAX_LENGTH} characters`;

/** Field validators for the category form (react-guidelines §Form Validation). */
export const categoryValidators = {
  /** `@NotBlank` — required category name. */
  name(value: string): string | undefined {
    if (value.trim().length === 0) {
      return NAME_REQUIRED;
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

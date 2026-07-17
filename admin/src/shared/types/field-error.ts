/**
 * One field-level validation error (dto-spec §5). Mirrors the frozen DTO
 * field-for-field.
 */
export interface FieldError {
  /** Offending field name. */
  readonly field: string;
  /** Validation message. */
  readonly message: string;
}

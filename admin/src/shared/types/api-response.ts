import type { FieldError } from './field-error';

/**
 * Standard success/error envelope wrapping every backend response (dto-spec §5).
 * Mirrors the frozen DTO field-for-field.
 *
 * On success, `data` is present and `errorCode` / `errors` are omitted; on a
 * business error, `data` is null and `errorCode` is present; on a validation
 * failure, `errors` carries the field-level messages.
 */
export interface ApiResponse<T> {
  /** True on success, false on error. */
  readonly success: boolean;
  /** Human-readable message (e.g. "OK"). */
  readonly message: string;
  /** Payload; null on error. */
  readonly data?: T | null;
  /** Machine error code; present on error only. */
  readonly errorCode?: string;
  /** Field-level validation errors; present on validation failure. */
  readonly errors?: readonly FieldError[];
  /** Server timestamp of the response (ISO-8601). */
  readonly timestamp: string;
}

import type { FieldError } from '@/shared/types/field-error';

interface AppErrorParams {
  readonly message: string;
  readonly statusCode?: number;
  readonly errorCode?: string;
  readonly errors?: readonly FieldError[];
  readonly isNetworkError?: boolean;
}

/**
 * A typed client-side error representing a failed API call — the React analog of
 * the Flutter `AppException` (react-guidelines §Error Handling).
 *
 * It carries the fields of the backend error envelope (error-spec §1) — the HTTP
 * [statusCode], the machine [errorCode], the user-safe [message], and the
 * field-level [errors] — and additionally represents a network failure where no
 * response was received ([isNetworkError]). It only represents an error; it
 * performs no error handling.
 */
export class AppError extends Error {
  /** HTTP status code of the response; undefined when no response was received. */
  readonly statusCode?: number;
  /** Machine-readable error code from the envelope; undefined for a network failure. */
  readonly errorCode?: string;
  /** Field-level validation errors; present only on a validation failure. */
  readonly errors?: readonly FieldError[];
  /** True when the request failed without any response (network failure). */
  readonly isNetworkError: boolean;

  constructor(params: AppErrorParams) {
    super(params.message);
    this.name = 'AppError';
    this.statusCode = params.statusCode;
    this.errorCode = params.errorCode;
    this.errors = params.errors;
    this.isNetworkError = params.isNetworkError ?? false;
    // Restore the prototype chain so `instanceof AppError` holds after transpile.
    Object.setPrototypeOf(this, AppError.prototype);
  }

  /** Creates an error for a network failure where no response was received. */
  static network(message: string): AppError {
    return new AppError({ message, isNetworkError: true });
  }
}

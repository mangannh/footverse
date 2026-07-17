import { AxiosError, type AxiosInstance } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

const NETWORK_FAILURE_MESSAGE = 'Unable to reach the server. Please check your connection.';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/**
 * Installs the error interceptor — the React analog of the Flutter
 * `ErrorInterceptor` (react-guidelines §Networking / §Error Handling).
 *
 * It translates every rejected request into an [AppError] so no raw transport
 * error leaves the networking layer. When the server answered, the error
 * envelope (error-spec §1) is parsed for its `message`, `errorCode`, and field
 * `errors`; when no response was received (timeout, socket, connection failure)
 * a network [AppError] is produced. An error already mapped upstream (by the
 * auth interceptor's retry pass) is passed through unchanged.
 */
export function installErrorInterceptor(client: AxiosInstance): void {
  client.interceptors.response.use(
    (response) => response,
    (error: unknown) => Promise.reject(toAppError(error)),
  );
}

function toAppError(error: unknown): AppError {
  if (error instanceof AppError) {
    return error;
  }
  if (!(error instanceof AxiosError)) {
    return new AppError({ message: UNEXPECTED_MESSAGE });
  }
  const response = error.response;
  if (response === undefined) {
    return AppError.network(NETWORK_FAILURE_MESSAGE);
  }
  return mapResponse(response.status, response.data);
}

function mapResponse(statusCode: number, data: unknown): AppError {
  if (isEnvelope(data)) {
    return new AppError({
      message: data.message,
      statusCode,
      errorCode: data.errorCode,
      errors: data.errors,
    });
  }
  return new AppError({ message: UNEXPECTED_MESSAGE, statusCode });
}

function isEnvelope(data: unknown): data is ApiResponse<unknown> {
  return (
    typeof data === 'object' &&
    data !== null &&
    'message' in data &&
    typeof (data as { message: unknown }).message === 'string'
  );
}

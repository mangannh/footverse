import type { AxiosInstance } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

import type { AuthResponse } from '../models/auth-response';
import type { LoginRequest } from '../models/login-request';
import type { RefreshTokenRequest } from '../models/refresh-token-request';
import type { UserResponse } from '../models/user-response';

const LOGIN_PATH = '/api/v1/auth/login';
const REFRESH_PATH = '/api/v1/auth/refresh';
const LOGOUT_PATH = '/api/v1/auth/logout';
const CURRENT_USER_PATH = '/api/v1/users/me';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/**
 * The typed client of the three frozen auth endpoints (dto-spec §20) — the React
 * analog of the Flutter `AuthRepository` (react-guidelines §Repository Contract).
 *
 * It only calls the API, unwraps the [ApiResponse] envelope, and returns the
 * typed payload — throwing [AppError] on failure (the injected client's error
 * interceptor has already mapped the transport error). It never touches token
 * storage, navigation, or session state; the session layer composes those.
 *
 * [refresh] is the typed client of `POST /auth/refresh`; the refresh *flow*
 * itself (single 401-refresh-retry) is owned by the Task 01 auth interceptor,
 * not this method — mirroring the frozen Flutter precedent.
 */
export class AuthRepository {
  constructor(private readonly client: AxiosInstance) {}

  login(request: LoginRequest): Promise<AuthResponse> {
    return this.authenticate(LOGIN_PATH, request);
  }

  refresh(request: RefreshTokenRequest): Promise<AuthResponse> {
    return this.authenticate(REFRESH_PATH, request);
  }

  async logout(request: RefreshTokenRequest): Promise<void> {
    await this.client.post<ApiResponse<void>>(LOGOUT_PATH, request);
  }

  /**
   * `GET /users/me` — the authenticated caller's own profile (dto-spec §20).
   * The backend is the single source of truth for the current user; the client
   * decodes no JWT and infers no field itself.
   */
  async getCurrentUser(): Promise<UserResponse> {
    const response = await this.client.get<ApiResponse<UserResponse>>(CURRENT_USER_PATH);
    return this.unwrapOrThrow(response.data.data);
  }

  private async authenticate(
    path: string,
    body: LoginRequest | RefreshTokenRequest,
  ): Promise<AuthResponse> {
    const response = await this.client.post<ApiResponse<AuthResponse>>(path, body);
    return this.unwrapOrThrow(response.data.data);
  }

  private unwrapOrThrow<T>(data: T | null | undefined): T {
    if (data === undefined || data === null) {
      throw new AppError({ message: UNEXPECTED_MESSAGE });
    }
    return data;
  }
}

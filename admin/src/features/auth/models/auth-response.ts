import type { UserResponse } from './user-response';

/**
 * Result of a successful login / refresh (dto-spec §6). Mirrors the frozen DTO
 * field-for-field. The access-token lifetime comes from [expiresIn] — never
 * hardcoded.
 */
export interface AuthResponse {
  readonly accessToken: string;
  readonly refreshToken: string;
  readonly expiresIn: number;
  readonly tokenType: string;
  readonly user: UserResponse;
}

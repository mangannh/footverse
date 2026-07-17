/**
 * Exchange a valid refresh token for a new token pair, or revoke it at logout
 * (dto-spec §6).
 */
export interface RefreshTokenRequest {
  readonly refreshToken: string;
}

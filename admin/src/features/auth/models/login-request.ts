/** Authenticate and obtain a JWT (dto-spec §6). */
export interface LoginRequest {
  readonly email: string;
  readonly password: string;
}

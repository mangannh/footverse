import type { Role } from './role';

/**
 * A user's profile (dto-spec §7). Passwords are never included. Mirrors the
 * frozen DTO field-for-field.
 */
export interface UserResponse {
  readonly id: number;
  readonly email: string;
  readonly fullName: string;
  readonly phone: string;
  readonly avatarUrl?: string;
  readonly role: Role;
  readonly enabled: boolean;
  readonly createdAt: string;
  readonly updatedAt: string;
}

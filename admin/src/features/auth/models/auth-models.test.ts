import { describe, expect, it } from 'vitest';

import type { AuthResponse } from './auth-response';
import type { LoginRequest } from './login-request';
import type { RefreshTokenRequest } from './refresh-token-request';
import type { UserResponse } from './user-response';

// Captured backend payloads (dto-spec §6/§7). Mirrors the Flutter
// `auth_models_test.dart` precedent: request types serialize field-for-field,
// response types deserialize a captured payload, and optional fields
// (`avatarUrl`) are omitted from the request/response JSON when unset.
function userJson(): Record<string, unknown> {
  return {
    id: 1,
    email: 'admin@footverse.com',
    fullName: 'Admin User',
    phone: '0901234567',
    role: 'ADMIN',
    enabled: true,
    createdAt: '2026-01-01T00:00:00',
    updatedAt: '2026-01-01T00:00:00',
    // no avatarUrl: optional field omitted by the backend when unset.
  };
}

describe('LoginRequest', () => {
  it('serializes field-for-field with no extra field', () => {
    const request: LoginRequest = { email: 'admin@footverse.com', password: 'secret123' };

    expect(JSON.parse(JSON.stringify(request))).toEqual({
      email: 'admin@footverse.com',
      password: 'secret123',
    });
  });
});

describe('RefreshTokenRequest', () => {
  it('serializes field-for-field', () => {
    const request: RefreshTokenRequest = { refreshToken: 'refresh-opaque' };

    expect(JSON.parse(JSON.stringify(request))).toEqual({ refreshToken: 'refresh-opaque' });
  });
});

describe('UserResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const user: UserResponse = JSON.parse(JSON.stringify(userJson()));

    expect(user).toMatchObject({
      id: 1,
      email: 'admin@footverse.com',
      fullName: 'Admin User',
      phone: '0901234567',
      role: 'ADMIN',
      enabled: true,
    });
    expect(user.avatarUrl).toBeUndefined();
  });

  it('deserializes an optional avatarUrl when present', () => {
    const payload = { ...userJson(), avatarUrl: 'https://example.com/avatar.png' };

    const user: UserResponse = JSON.parse(JSON.stringify(payload));

    expect(user.avatarUrl).toBe('https://example.com/avatar.png');
  });
});

describe('AuthResponse', () => {
  it('deserializes a captured payload carrying the nested user', () => {
    const payload = {
      accessToken: 'access-jwt',
      refreshToken: 'refresh-opaque',
      expiresIn: 900,
      tokenType: 'Bearer',
      user: userJson(),
    };

    const auth: AuthResponse = JSON.parse(JSON.stringify(payload));

    expect(auth.accessToken).toBe('access-jwt');
    expect(auth.expiresIn).toBe(900);
    expect(auth.tokenType).toBe('Bearer');
    expect(auth.user.role).toBe('ADMIN');
  });
});

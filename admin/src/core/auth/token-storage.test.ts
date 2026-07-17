import { beforeEach, describe, expect, it } from 'vitest';

import { tokenStorage } from './token-storage';

describe('tokenStorage', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('round-trips the token pair through storage', () => {
    tokenStorage.saveTokens('access-1', 'refresh-1');

    expect(tokenStorage.readAccessToken()).toBe('access-1');
    expect(tokenStorage.readRefreshToken()).toBe('refresh-1');
  });

  it('returns null when no token is stored', () => {
    expect(tokenStorage.readAccessToken()).toBeNull();
    expect(tokenStorage.readRefreshToken()).toBeNull();
  });

  it('clears both tokens', () => {
    tokenStorage.saveTokens('access-1', 'refresh-1');

    tokenStorage.clearTokens();

    expect(tokenStorage.readAccessToken()).toBeNull();
    expect(tokenStorage.readRefreshToken()).toBeNull();
  });
});

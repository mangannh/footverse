import { act, renderHook } from '@testing-library/react';
import type { ReactNode } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { tokenStorage } from '@/core/auth/token-storage';
import { AppError } from '@/core/error/app-error';

import { SessionProvider } from './session-provider';
import { useSession } from './use-session';
import type { AuthResponse } from '../models/auth-response';
import type { Role } from '../models/role';
import type { AuthRepository } from '../repositories/auth-repository';

function authResponse(role: Role): AuthResponse {
  return {
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    expiresIn: 900,
    tokenType: 'Bearer',
    user: {
      id: 1,
      email: 'user@footverse.com',
      fullName: 'User',
      phone: '0900000000',
      role,
      enabled: true,
      createdAt: '2026-01-01T00:00:00',
      updatedAt: '2026-01-01T00:00:00',
    },
  };
}

interface FakeRepo {
  login: ReturnType<typeof vi.fn>;
  logout: ReturnType<typeof vi.fn>;
  getCurrentUser?: ReturnType<typeof vi.fn>;
}

function userResponse(role: Role) {
  return authResponse(role).user;
}

function makeWrapper(repo: FakeRepo) {
  return function Wrapper({ children }: { children: ReactNode }) {
    return (
      <SessionProvider authRepository={repo as unknown as AuthRepository}>
        {children}
      </SessionProvider>
    );
  };
}

describe('SessionProvider / useSession', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('signs in an ADMIN, exposing the user and persisting the tokens', async () => {
    const repo: FakeRepo = {
      login: vi.fn().mockResolvedValue(authResponse('ADMIN')),
      logout: vi.fn(),
    };
    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });

    expect(result.current.isAuthenticated).toBe(false);

    await act(async () => {
      await result.current.login({ email: 'admin@footverse.com', password: 'secret1' });
    });

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.user?.role).toBe('ADMIN');
    expect(tokenStorage.readAccessToken()).toBe('access-1');
    expect(tokenStorage.readRefreshToken()).toBe('refresh-1');
  });

  it('rejects a CUSTOMER client-side, clearing tokens and staying signed out', async () => {
    const repo: FakeRepo = {
      login: vi.fn().mockResolvedValue(authResponse('CUSTOMER')),
      logout: vi.fn(),
    };
    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });

    await act(async () => {
      await expect(
        result.current.login({ email: 'customer@footverse.com', password: 'secret1' }),
      ).rejects.toBeInstanceOf(AppError);
    });

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.user).toBeNull();
    expect(tokenStorage.readAccessToken()).toBeNull();
    // No admin request is issued: only the single login call happened.
    expect(repo.login).toHaveBeenCalledTimes(1);
  });

  it('rethrows an invalid-credential AppError and stays signed out', async () => {
    const repo: FakeRepo = {
      login: vi.fn().mockRejectedValue(new AppError({ message: 'Invalid', statusCode: 401 })),
      logout: vi.fn(),
    };
    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });

    await act(async () => {
      await expect(
        result.current.login({ email: 'admin@footverse.com', password: 'wrong' }),
      ).rejects.toBeInstanceOf(AppError);
    });

    expect(result.current.isAuthenticated).toBe(false);
  });

  it('is single-flight: a concurrent login is ignored', async () => {
    let resolveLogin: (value: AuthResponse) => void = () => undefined;
    const repo: FakeRepo = {
      login: vi.fn().mockImplementation(
        () =>
          new Promise<AuthResponse>((resolve) => {
            resolveLogin = resolve;
          }),
      ),
      logout: vi.fn(),
    };
    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });

    await act(async () => {
      const first = result.current.login({ email: 'admin@footverse.com', password: 'secret1' });
      const second = result.current.login({ email: 'admin@footverse.com', password: 'secret1' });
      resolveLogin(authResponse('ADMIN'));
      await Promise.all([first, second]);
    });

    expect(repo.login).toHaveBeenCalledTimes(1);
    expect(result.current.isAuthenticated).toBe(true);
  });

  it('logout always clears the local session, even when the server call fails', async () => {
    const repo: FakeRepo = {
      login: vi.fn().mockResolvedValue(authResponse('ADMIN')),
      logout: vi.fn().mockRejectedValue(new AppError({ message: 'logout failed' })),
    };
    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });

    await act(async () => {
      await result.current.login({ email: 'admin@footverse.com', password: 'secret1' });
    });
    expect(result.current.isAuthenticated).toBe(true);

    await act(async () => {
      await result.current.logout();
    });

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.user).toBeNull();
    expect(tokenStorage.readAccessToken()).toBeNull();
    expect(repo.logout).toHaveBeenCalledWith({ refreshToken: 'refresh-1' });
  });

  it('restores no session when no token is persisted', () => {
    const repo: FakeRepo = { login: vi.fn(), logout: vi.fn(), getCurrentUser: vi.fn() };
    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });

    expect(result.current.isInitializing).toBe(false);
    expect(result.current.isAuthenticated).toBe(false);
    expect(repo.getCurrentUser).not.toHaveBeenCalled();
  });

  it('restores the session via GET /users/me when a token is persisted', async () => {
    tokenStorage.saveTokens('access-1', 'refresh-1');
    const repo: FakeRepo = {
      login: vi.fn(),
      logout: vi.fn(),
      getCurrentUser: vi.fn().mockResolvedValue(userResponse('ADMIN')),
    };

    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });
    expect(result.current.isInitializing).toBe(true);

    await act(async () => {
      await Promise.resolve();
    });

    expect(repo.getCurrentUser).toHaveBeenCalledTimes(1);
    expect(result.current.isInitializing).toBe(false);
    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.user?.role).toBe('ADMIN');
    // Restore never decodes a token or re-saves it; the persisted pair is untouched.
    expect(tokenStorage.readAccessToken()).toBe('access-1');
  });

  it('clears the token pair and stays signed out when restore fails', async () => {
    tokenStorage.saveTokens('stale-access', 'stale-refresh');
    const repo: FakeRepo = {
      login: vi.fn(),
      logout: vi.fn(),
      getCurrentUser: vi
        .fn()
        .mockRejectedValue(new AppError({ message: 'Unauthorized', statusCode: 401 })),
    };

    const { result } = renderHook(() => useSession(), { wrapper: makeWrapper(repo) });

    await act(async () => {
      await Promise.resolve();
    });

    expect(result.current.isInitializing).toBe(false);
    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.user).toBeNull();
    expect(tokenStorage.readAccessToken()).toBeNull();
    expect(tokenStorage.readRefreshToken()).toBeNull();
  });
});

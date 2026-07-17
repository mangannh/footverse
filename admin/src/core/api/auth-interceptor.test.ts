import {
  AxiosError,
  AxiosHeaders,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from 'axios';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { tokenStorage } from '@/core/auth/token-storage';
import { AppError } from '@/core/error/app-error';
import { ROUTES } from '@/core/router/routes';

import { httpClient } from './http-client';

const AUTHORIZATION = 'Authorization';

function okResponse<T>(config: InternalAxiosRequestConfig, data: T): AxiosResponse<T> {
  return { data, status: 200, statusText: 'OK', headers: new AxiosHeaders(), config };
}

function unauthorized(config: InternalAxiosRequestConfig): AxiosError {
  const response: AxiosResponse = {
    data: {
      success: false,
      message: 'Unauthorized',
      errorCode: 'UNAUTHORIZED',
      timestamp: '2026-01-01T00:00:00',
    },
    status: 401,
    statusText: 'Unauthorized',
    headers: new AxiosHeaders(),
    config,
  };
  return new AxiosError('Unauthorized', 'ERR_BAD_REQUEST', config, {}, response);
}

function refreshEnvelope(accessToken: string, refreshToken: string): unknown {
  return {
    success: true,
    message: 'OK',
    data: { accessToken, refreshToken },
    timestamp: '2026-01-01T00:00:00',
  };
}

describe('auth interceptor', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('attaches the bearer token when one is stored', async () => {
    tokenStorage.saveTokens('access-1', 'refresh-1');
    let authHeader: unknown;
    httpClient.defaults.adapter = async (config) => {
      authHeader = config.headers.get(AUTHORIZATION);
      return okResponse(config, { ok: true });
    };

    await httpClient.get('/api/v1/protected');

    expect(authHeader).toBe('Bearer access-1');
  });

  it('sends no bearer when no token is stored', async () => {
    let authHeader: unknown;
    httpClient.defaults.adapter = async (config) => {
      authHeader = config.headers.get(AUTHORIZATION);
      return okResponse(config, { ok: true });
    };

    await httpClient.get('/api/v1/protected');

    expect(authHeader ?? null).toBeNull();
  });

  it('refreshes once and retries with the rotated token on a 401', async () => {
    tokenStorage.saveTokens('access-1', 'refresh-1');
    const calls: { url: string; auth: unknown; retried: boolean }[] = [];
    httpClient.defaults.adapter = async (config) => {
      const url = config.url ?? '';
      const retried = (config as { retried?: boolean }).retried === true;
      calls.push({ url, auth: config.headers.get(AUTHORIZATION), retried });

      if (url.endsWith('/auth/refresh')) {
        return okResponse(config, refreshEnvelope('access-2', 'refresh-2'));
      }
      if (url.endsWith('/protected') && !retried) {
        throw unauthorized(config);
      }
      return okResponse(config, { ok: true });
    };

    const response = await httpClient.get('/api/v1/protected');

    expect(response.status).toBe(200);
    expect(tokenStorage.readAccessToken()).toBe('access-2');
    expect(tokenStorage.readRefreshToken()).toBe('refresh-2');

    const refreshCalls = calls.filter((c) => c.url.endsWith('/auth/refresh'));
    expect(refreshCalls).toHaveLength(1);

    const retriedCall = calls.find((c) => c.url.endsWith('/protected') && c.retried);
    expect(retriedCall?.auth).toBe('Bearer access-2');
  });

  it('clears tokens and redirects to login when the refresh fails', async () => {
    tokenStorage.saveTokens('access-1', 'refresh-1');
    const assign = vi.fn();
    vi.stubGlobal('location', { assign });
    let refreshCount = 0;
    httpClient.defaults.adapter = async (config) => {
      if ((config.url ?? '').endsWith('/auth/refresh')) {
        refreshCount += 1;
      }
      throw unauthorized(config);
    };

    await expect(httpClient.get('/api/v1/protected')).rejects.toBeInstanceOf(AppError);

    expect(tokenStorage.readAccessToken()).toBeNull();
    expect(tokenStorage.readRefreshToken()).toBeNull();
    expect(assign).toHaveBeenCalledWith(ROUTES.login);
    // No refresh loop: exactly one refresh attempt.
    expect(refreshCount).toBe(1);
  });

  it('does not refresh when a 401 comes from an auth endpoint', async () => {
    tokenStorage.saveTokens('access-1', 'refresh-1');
    let refreshCount = 0;
    httpClient.defaults.adapter = async (config) => {
      if ((config.url ?? '').endsWith('/auth/refresh')) {
        refreshCount += 1;
      }
      throw unauthorized(config);
    };

    await expect(
      httpClient.post('/api/v1/auth/login', { email: 'a@b.co', password: 'secret1' }),
    ).rejects.toBeInstanceOf(AppError);

    expect(refreshCount).toBe(0);
  });
});

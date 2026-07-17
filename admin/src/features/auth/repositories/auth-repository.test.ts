import {
  AxiosError,
  AxiosHeaders,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from 'axios';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { httpClient } from '@/core/api/http-client';
import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

import { AuthRepository } from './auth-repository';
import type { AuthResponse } from '../models/auth-response';
import type { UserResponse } from '../models/user-response';

const adminUser: UserResponse = {
  id: 1,
  email: 'admin@footverse.com',
  fullName: 'Admin',
  phone: '0900000000',
  role: 'ADMIN',
  enabled: true,
  createdAt: '2026-01-01T00:00:00',
  updatedAt: '2026-01-01T00:00:00',
};
const authData: AuthResponse = {
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  expiresIn: 900,
  tokenType: 'Bearer',
  user: adminUser,
};
const authEnvelope: ApiResponse<AuthResponse> = {
  success: true,
  message: 'OK',
  data: authData,
  timestamp: '2026-01-01T00:00:00',
};

interface CapturedRequest {
  method: string | undefined;
  url: string | undefined;
  body: unknown;
}

function okResponse<T>(config: InternalAxiosRequestConfig, data: T): AxiosResponse<T> {
  return { data, status: 200, statusText: 'OK', headers: new AxiosHeaders(), config };
}

function errorResponse(
  config: InternalAxiosRequestConfig,
  status: number,
  data: unknown,
): AxiosError {
  const response: AxiosResponse = {
    data,
    status,
    statusText: '',
    headers: new AxiosHeaders(),
    config,
  };
  return new AxiosError('Request failed', 'ERR_BAD_REQUEST', config, {}, response);
}

describe('AuthRepository', () => {
  const repository = new AuthRepository(httpClient);

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('login issues POST /auth/login with the credentials and returns the payload', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        body: JSON.parse(config.data as string),
      };
      return okResponse(config, authEnvelope);
    };

    const result = await repository.login({ email: 'admin@footverse.com', password: 'secret1' });

    expect(captured).toEqual({
      method: 'post',
      url: '/api/v1/auth/login',
      body: { email: 'admin@footverse.com', password: 'secret1' },
    });
    expect(result).toEqual(authData);
  });

  it('refresh issues POST /auth/refresh with the refresh token', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        body: JSON.parse(config.data as string),
      };
      return okResponse(config, authEnvelope);
    };

    const result = await repository.refresh({ refreshToken: 'refresh-1' });

    expect(captured).toEqual({
      method: 'post',
      url: '/api/v1/auth/refresh',
      body: { refreshToken: 'refresh-1' },
    });
    expect(result).toEqual(authData);
  });

  it('logout issues POST /auth/logout with the refresh token', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        body: JSON.parse(config.data as string),
      };
      return okResponse(config, {
        success: true,
        message: 'OK',
        data: null,
        timestamp: '2026-01-01T00:00:00',
      });
    };

    await repository.logout({ refreshToken: 'refresh-1' });

    expect(captured).toEqual({
      method: 'post',
      url: '/api/v1/auth/logout',
      body: { refreshToken: 'refresh-1' },
    });
  });

  it('surfaces an invalid-credential envelope as AppError with the errorCode intact', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 401, {
        success: false,
        message: 'Invalid email or password',
        errorCode: 'INVALID_CREDENTIALS',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.login({ email: 'admin@footverse.com', password: 'wrong' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 401,
      errorCode: 'INVALID_CREDENTIALS',
    });
  });
});

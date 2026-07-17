import {
  AxiosError,
  AxiosHeaders,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from 'axios';
import { afterEach, describe, expect, it } from 'vitest';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

import { httpClient } from './http-client';

// The three envelope shapes must type-check (Task 01 DoD): a success, a
// business error (errorCode + null data), and a validation error (errors[]).
const successEnvelope: ApiResponse<{ id: number }> = {
  success: true,
  message: 'OK',
  data: { id: 1 },
  timestamp: '2026-01-01T00:00:00',
};
const businessErrorEnvelope: ApiResponse<never> = {
  success: false,
  message: 'Brand not found',
  data: null,
  errorCode: 'BRAND_NOT_FOUND',
  timestamp: '2026-01-01T00:00:00',
};
const validationEnvelope: ApiResponse<never> = {
  success: false,
  message: 'Validation failed',
  errorCode: 'VALIDATION_ERROR',
  errors: [{ field: 'name', message: 'must not be blank' }],
  timestamp: '2026-01-01T00:00:00',
};

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

describe('envelope types', () => {
  it('models the three envelope shapes', () => {
    expect(successEnvelope.success).toBe(true);
    expect(businessErrorEnvelope.errorCode).toBe('BRAND_NOT_FOUND');
    expect(validationEnvelope.errors).toHaveLength(1);
  });
});

describe('error interceptor', () => {
  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('maps a business error envelope to AppError with its errorCode', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Brand name already exists',
        errorCode: 'BRAND_NAME_DUPLICATED',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = httpClient.get('/api/v1/brands');

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      message: 'Brand name already exists',
      statusCode: 409,
      errorCode: 'BRAND_NAME_DUPLICATED',
      isNetworkError: false,
    });
  });

  it('maps a forbidden envelope (403, non-ADMIN role) to AppError with its errorCode', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 403, {
        success: false,
        message: 'You cannot access this resource',
        errorCode: 'FORBIDDEN',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = httpClient.post('/api/v1/brands', { name: 'Nike' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      message: 'You cannot access this resource',
      statusCode: 403,
      errorCode: 'FORBIDDEN',
    });
  });

  it('maps a validation envelope preserving the field errors', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 400, {
        success: false,
        message: 'Validation failed',
        errorCode: 'VALIDATION_ERROR',
        errors: [{ field: 'name', message: 'must not be blank' }],
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = httpClient.post('/api/v1/brands', {});

    await expect(promise).rejects.toMatchObject({
      errorCode: 'VALIDATION_ERROR',
      errors: [{ field: 'name', message: 'must not be blank' }],
    });
  });

  it('maps a response-less failure to a network AppError', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw new AxiosError('Network Error', 'ERR_NETWORK', config, {});
    };

    const promise = httpClient.get('/api/v1/brands');

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ isNetworkError: true });
  });
});

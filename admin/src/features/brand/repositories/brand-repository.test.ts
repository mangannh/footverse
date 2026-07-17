import {
  AxiosError,
  AxiosHeaders,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from 'axios';
import { afterEach, describe, expect, it } from 'vitest';

import { httpClient } from '@/core/api/http-client';
import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

import { BrandRepository } from './brand-repository';
import type { BrandResponse } from '../models/brand-response';

const brand: BrandResponse = {
  id: 1,
  name: 'Nike',
  logoUrl: 'https://example.com/nike.png',
  description: 'Sportswear',
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

describe('BrandRepository', () => {
  const repository = new BrandRepository(httpClient);

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('list issues GET /brands and returns the unwrapped array', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = { method: config.method, url: config.url, body: config.data };
      const envelope: ApiResponse<BrandResponse[]> = {
        success: true,
        message: 'OK',
        data: [brand],
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.list();

    expect(captured).toMatchObject({ method: 'get', url: '/api/v1/brands' });
    expect(result).toEqual([brand]);
  });

  it('create issues POST /brands with the request body and returns the created brand', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        body: JSON.parse(config.data as string),
      };
      const envelope: ApiResponse<BrandResponse> = {
        success: true,
        message: 'Created',
        data: brand,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.create({
      name: 'Nike',
      logoUrl: 'https://example.com/nike.png',
    });

    expect(captured).toEqual({
      method: 'post',
      url: '/api/v1/brands',
      body: { name: 'Nike', logoUrl: 'https://example.com/nike.png' },
    });
    expect(result).toEqual(brand);
  });

  it('update issues PUT /brands/{id} with the request body and returns the updated brand', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        body: JSON.parse(config.data as string),
      };
      const envelope: ApiResponse<BrandResponse> = {
        success: true,
        message: 'OK',
        data: brand,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.update(1, { name: 'Nike' });

    expect(captured).toEqual({ method: 'put', url: '/api/v1/brands/1', body: { name: 'Nike' } });
    expect(result).toEqual(brand);
  });

  it('remove issues DELETE /brands/{id}', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = { method: config.method, url: config.url, body: config.data };
      const envelope: ApiResponse<void> = {
        success: true,
        message: 'OK',
        data: null,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    await repository.remove(1);

    expect(captured).toMatchObject({ method: 'delete', url: '/api/v1/brands/1' });
  });

  it('surfaces a duplicate-name conflict as AppError with BRAND_NAME_DUPLICATED', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Brand name already exists',
        errorCode: 'BRAND_NAME_DUPLICATED',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.create({ name: 'Nike' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 409,
      errorCode: 'BRAND_NAME_DUPLICATED',
    });
  });

  it('surfaces a referenced-delete conflict as AppError with BRAND_IN_USE', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Brand is still referenced by products',
        errorCode: 'BRAND_IN_USE',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.remove(1);

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 409, errorCode: 'BRAND_IN_USE' });
  });

  it('surfaces a not-found update as AppError with BRAND_NOT_FOUND', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 404, {
        success: false,
        message: 'Brand not found',
        errorCode: 'BRAND_NOT_FOUND',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.update(999, { name: 'Nike' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 404, errorCode: 'BRAND_NOT_FOUND' });
  });
});

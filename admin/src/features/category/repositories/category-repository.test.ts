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

import { CategoryRepository } from './category-repository';
import type { CategoryResponse } from '../models/category-response';

const category: CategoryResponse = {
  id: 1,
  name: 'Running Shoes',
  description: 'Shoes built for running',
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

describe('CategoryRepository', () => {
  const repository = new CategoryRepository(httpClient);

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('list issues GET /categories and returns the unwrapped array', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = { method: config.method, url: config.url, body: config.data };
      const envelope: ApiResponse<CategoryResponse[]> = {
        success: true,
        message: 'OK',
        data: [category],
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.list();

    expect(captured).toMatchObject({ method: 'get', url: '/api/v1/categories' });
    expect(result).toEqual([category]);
  });

  it('create issues POST /categories with the request body and returns the created category', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        body: JSON.parse(config.data as string),
      };
      const envelope: ApiResponse<CategoryResponse> = {
        success: true,
        message: 'Created',
        data: category,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.create({ name: 'Running Shoes' });

    expect(captured).toEqual({
      method: 'post',
      url: '/api/v1/categories',
      body: { name: 'Running Shoes' },
    });
    expect(result).toEqual(category);
  });

  it('update issues PUT /categories/{id} with the request body and returns the updated category', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        body: JSON.parse(config.data as string),
      };
      const envelope: ApiResponse<CategoryResponse> = {
        success: true,
        message: 'OK',
        data: category,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.update(1, { name: 'Running Shoes' });

    expect(captured).toEqual({
      method: 'put',
      url: '/api/v1/categories/1',
      body: { name: 'Running Shoes' },
    });
    expect(result).toEqual(category);
  });

  it('remove issues DELETE /categories/{id}', async () => {
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

    expect(captured).toMatchObject({ method: 'delete', url: '/api/v1/categories/1' });
  });

  it('surfaces a duplicate-name conflict as AppError with CATEGORY_NAME_DUPLICATED', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Category name already exists',
        errorCode: 'CATEGORY_NAME_DUPLICATED',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.create({ name: 'Running Shoes' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 409,
      errorCode: 'CATEGORY_NAME_DUPLICATED',
    });
  });

  it('surfaces a referenced-delete conflict as AppError with CATEGORY_IN_USE', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Category is still referenced by products',
        errorCode: 'CATEGORY_IN_USE',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.remove(1);

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 409, errorCode: 'CATEGORY_IN_USE' });
  });

  it('surfaces a not-found update as AppError with CATEGORY_NOT_FOUND', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 404, {
        success: false,
        message: 'Category not found',
        errorCode: 'CATEGORY_NOT_FOUND',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.update(999, { name: 'Running Shoes' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 404,
      errorCode: 'CATEGORY_NOT_FOUND',
    });
  });
});

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
import type { PageResponse } from '@/shared/types/page-response';

import { CouponRepository } from './coupon-repository';
import type { CouponResponse } from '../models/coupon-response';

const coupon: CouponResponse = {
  id: 1,
  code: 'SUMMER10',
  name: 'Summer Sale',
  description: '10% off',
  discountType: 'PERCENT',
  discountValue: 10,
  minOrderAmount: 50,
  maxDiscountAmount: 20,
  startAt: '2026-01-01T00:00:00',
  endAt: '2026-02-01T00:00:00',
  usageLimit: 100,
  usedCount: 0,
  enabled: true,
};

interface CapturedRequest {
  method: string | undefined;
  url: string | undefined;
  params: unknown;
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

describe('CouponRepository', () => {
  const repository = new CouponRepository(httpClient);

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('list issues GET /coupons and returns the unwrapped page', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      const page: PageResponse<CouponResponse> = {
        content: [coupon],
        page: 0,
        size: 20,
        totalElements: 1,
        totalPages: 1,
        last: true,
      };
      const envelope: ApiResponse<PageResponse<CouponResponse>> = {
        success: true,
        message: 'OK',
        data: page,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.list({ page: 0, size: 20 });

    expect(captured).toMatchObject({
      method: 'get',
      url: '/api/v1/coupons',
      params: { page: 0, size: 20 },
    });
    expect(result).toEqual({
      content: [coupon],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    });
  });

  it('create issues POST /coupons with the request body and returns the created coupon', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: JSON.parse(config.data as string),
      };
      const envelope: ApiResponse<CouponResponse> = {
        success: true,
        message: 'Created',
        data: coupon,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.create({
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      enabled: true,
    });

    expect(captured).toEqual({
      method: 'post',
      url: '/api/v1/coupons',
      params: undefined,
      body: {
        code: 'SUMMER10',
        name: 'Summer Sale',
        discountType: 'PERCENT',
        discountValue: 10,
        minOrderAmount: 50,
        startAt: '2026-01-01T00:00:00',
        endAt: '2026-02-01T00:00:00',
        enabled: true,
      },
    });
    expect(result).toEqual(coupon);
  });

  it('update issues PUT /coupons/{id} with the request body and returns the updated coupon', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: JSON.parse(config.data as string),
      };
      const envelope: ApiResponse<CouponResponse> = {
        success: true,
        message: 'OK',
        data: coupon,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.update(1, {
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 15,
      minOrderAmount: 50,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      enabled: true,
    });

    expect(captured).toMatchObject({ method: 'put', url: '/api/v1/coupons/1' });
    expect(result).toEqual(coupon);
  });

  it('surfaces a duplicate-code conflict as AppError with COUPON_CODE_DUPLICATED', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Coupon code already exists',
        errorCode: 'COUPON_CODE_DUPLICATED',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.create({
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      enabled: true,
    });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 409,
      errorCode: 'COUPON_CODE_DUPLICATED',
    });
  });

  it('surfaces a not-found update as AppError with COUPON_NOT_FOUND', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 404, {
        success: false,
        message: 'Coupon not found',
        errorCode: 'COUPON_NOT_FOUND',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.update(999, {
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      enabled: true,
    });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 404, errorCode: 'COUPON_NOT_FOUND' });
  });

  it('surfaces an invalid date range as AppError with COUPON_INVALID_DATE_RANGE', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 400, {
        success: false,
        message: 'Coupon end date must be after start date',
        errorCode: 'COUPON_INVALID_DATE_RANGE',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.create({
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      startAt: '2026-02-01T00:00:00',
      endAt: '2026-01-01T00:00:00',
      enabled: true,
    });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 400,
      errorCode: 'COUPON_INVALID_DATE_RANGE',
    });
  });
});

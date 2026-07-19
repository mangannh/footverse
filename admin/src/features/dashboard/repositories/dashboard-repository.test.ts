import {
  AxiosError,
  AxiosHeaders,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from 'axios';
import { afterEach, describe, expect, it } from 'vitest';

import { httpClient } from '@/core/api/http-client';
import { AppError } from '@/core/error/app-error';
import type { AdminOrderSummaryResponse } from '@/features/order/models/admin-order-summary-response';
import type { ApiResponse } from '@/shared/types/api-response';

import { DashboardRepository } from './dashboard-repository';
import type { DashboardResponse } from '../models/dashboard-response';

const recentOrder: AdminOrderSummaryResponse = {
  id: 5,
  orderCode: 'FV-ORDER-5',
  status: 'PENDING',
  paymentStatus: 'UNPAID',
  total: 30200,
  itemCount: 5,
  createdAt: '2026-01-01T00:00:00',
  customerId: 42,
  customerFullName: 'Jane Doe',
  customerEmail: 'jane@example.com',
  customerPhone: '0900000001',
};

const dashboard: DashboardResponse = {
  totalRevenue: 500000,
  totalOrders: 12,
  grossProfit: 120000,
  profitLinesWithCost: 8,
  profitLinesTotal: 10,
  ordersByStatus: [
    { status: 'PENDING', count: 3 },
    { status: 'CONFIRMED', count: 0 },
    { status: 'SHIPPING', count: 0 },
    { status: 'DELIVERED', count: 9 },
    { status: 'CANCELLED', count: 0 },
  ],
  monthlyRevenue: [{ year: 2026, month: 7, revenue: 500000, orderCount: 12 }],
  bestSellingProducts: [
    {
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: 'https://example.com/air-force-1.png',
      quantitySold: 10,
      revenue: 1000,
    },
  ],
  recentOrders: [recentOrder],
};

interface CapturedRequest {
  method: string | undefined;
  url: string | undefined;
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

describe('DashboardRepository', () => {
  const repository = new DashboardRepository(httpClient);

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('get issues GET /admin/dashboard and returns the unwrapped response', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = { method: config.method, url: config.url };
      const envelope: ApiResponse<DashboardResponse> = {
        success: true,
        message: 'OK',
        data: dashboard,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.get();

    expect(captured).toMatchObject({ method: 'get', url: '/api/v1/admin/dashboard' });
    expect(result).toEqual(dashboard);
    expect(result.recentOrders[0]?.customerFullName).toBe('Jane Doe');
  });

  it('surfaces a non-ADMIN forbidden response as AppError with FORBIDDEN', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 403, {
        success: false,
        message: 'You cannot access this resource',
        errorCode: 'FORBIDDEN',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.get();

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 403, errorCode: 'FORBIDDEN' });
  });

  it('surfaces an unauthenticated response as AppError with UNAUTHORIZED', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 401, {
        success: false,
        message: 'Authentication required',
        errorCode: 'UNAUTHORIZED',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.get();

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 401, errorCode: 'UNAUTHORIZED' });
  });
});

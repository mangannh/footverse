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

import { OrderRepository } from './order-repository';
import type { AdminOrderDetailResponse } from '../models/admin-order-detail-response';
import type { AdminOrderSummaryResponse } from '../models/admin-order-summary-response';

const summary: AdminOrderSummaryResponse = {
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

const detail: AdminOrderDetailResponse = {
  id: 9,
  orderCode: 'FV-ORDER-9',
  status: 'PENDING',
  paymentMethod: 'COD',
  paymentStatus: 'UNPAID',
  subtotal: 200,
  discountAmount: 0,
  shippingFee: 30000,
  total: 30200,
  couponCode: null,
  shippingRecipientName: 'Jane',
  shippingRecipientPhone: '0900000000',
  shippingProvince: 'HCM',
  shippingDistrict: 'D1',
  shippingWard: 'W1',
  shippingStreetAddress: '1 Street',
  note: null,
  items: [
    {
      id: 1,
      productVariantId: 7,
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: 'https://example.com/air-force-1.png',
      color: 'Black',
      size: '42',
      unitPrice: 100,
      quantity: 2,
      lineTotal: 200,
    },
  ],
  createdAt: '2026-01-01T00:00:00',
  cancelledAt: null,
  deliveredAt: null,
  customerId: 42,
  customerFullName: 'Jane Doe',
  customerEmail: 'jane@example.com',
  customerPhone: '0900000001',
};

interface CapturedRequest {
  method: string | undefined;
  url: string | undefined;
  params: Record<string, unknown> | undefined;
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

function parsedBody(config: InternalAxiosRequestConfig): unknown {
  return typeof config.data === 'string' ? JSON.parse(config.data) : config.data;
}

describe('OrderRepository', () => {
  const repository = new OrderRepository(httpClient);

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('list issues GET /admin/orders and returns the unwrapped page', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params as Record<string, unknown> | undefined,
        body: config.data,
      };
      const page: PageResponse<AdminOrderSummaryResponse> = {
        content: [summary],
        page: 0,
        size: 20,
        totalElements: 1,
        totalPages: 1,
        last: true,
      };
      const envelope: ApiResponse<PageResponse<AdminOrderSummaryResponse>> = {
        success: true,
        message: 'OK',
        data: page,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.list({ page: 0, size: 20 });

    expect(captured).toMatchObject({ method: 'get', url: '/api/v1/admin/orders' });
    expect(captured?.params?.page).toBe(0);
    expect(captured?.params?.size).toBe(20);
    expect(captured?.params?.status).toBeUndefined();
    expect(captured?.params?.orderCode).toBeUndefined();
    expect(result).toEqual({
      content: [summary],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    });
  });

  it('list with no params omits status and orderCode entirely', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      return okResponse(config, {
        success: true,
        message: 'OK',
        data: { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, last: true },
        timestamp: '2026-01-01T00:00:00',
      });
    };

    await repository.list();

    expect(captured?.params?.status).toBeUndefined();
    expect(captured?.params?.orderCode).toBeUndefined();
  });

  it('list sends status alone when only status is supplied', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      return okResponse(config, {
        success: true,
        message: 'OK',
        data: { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, last: true },
        timestamp: '2026-01-01T00:00:00',
      });
    };

    await repository.list({ status: 'DELIVERED' });

    expect(captured?.params?.status).toBe('DELIVERED');
    expect(captured?.params?.orderCode).toBeUndefined();
  });

  it('list sends orderCode alone when only orderCode is supplied', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      return okResponse(config, {
        success: true,
        message: 'OK',
        data: { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, last: true },
        timestamp: '2026-01-01T00:00:00',
      });
    };

    await repository.list({ orderCode: 'FV-2026' });

    expect(captured?.params?.orderCode).toBe('FV-2026');
    expect(captured?.params?.status).toBeUndefined();
  });

  it('list sends status and orderCode together when both are supplied', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      return okResponse(config, {
        success: true,
        message: 'OK',
        data: { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, last: true },
        timestamp: '2026-01-01T00:00:00',
      });
    };

    await repository.list({ status: 'PENDING', orderCode: 'FV-2026' });

    expect(captured?.params?.status).toBe('PENDING');
    expect(captured?.params?.orderCode).toBe('FV-2026');
  });

  it('list never sends a blank orderCode — it is dropped, not sent as an empty string', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      return okResponse(config, {
        success: true,
        message: 'OK',
        data: { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, last: true },
        timestamp: '2026-01-01T00:00:00',
      });
    };

    await repository.list({ orderCode: '' });

    expect(captured?.params?.orderCode).toBeUndefined();
  });

  it('get issues GET /admin/orders/{id} and returns the unwrapped admin detail', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params as Record<string, unknown> | undefined,
        body: config.data,
      };
      const envelope: ApiResponse<AdminOrderDetailResponse> = {
        success: true,
        message: 'OK',
        data: detail,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.get(9);

    expect(captured).toMatchObject({ method: 'get', url: '/api/v1/admin/orders/9' });
    expect(result).toEqual(detail);
    expect(result.customerFullName).toBe('Jane Doe');
  });

  it('updateStatus issues PATCH /orders/{id}/status — the customer-path endpoint, not /admin/orders', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params as Record<string, unknown> | undefined,
        body: parsedBody(config),
      };
      const envelope: ApiResponse<AdminOrderDetailResponse> = {
        success: true,
        message: 'OK',
        data: { ...detail, status: 'CONFIRMED' },
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.updateStatus(9, { status: 'CONFIRMED' });

    expect(captured).toMatchObject({
      method: 'patch',
      url: '/api/v1/orders/9/status',
      body: { status: 'CONFIRMED' },
    });
    expect(result.status).toBe('CONFIRMED');
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

    const promise = repository.list({ page: 0, size: 20 });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 403, errorCode: 'FORBIDDEN' });
  });

  it('surfaces a not-found order as AppError with ORDER_NOT_FOUND', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 404, {
        success: false,
        message: 'Order not found',
        errorCode: 'ORDER_NOT_FOUND',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.get(999);

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({ statusCode: 404, errorCode: 'ORDER_NOT_FOUND' });
  });

  it('surfaces a non-cancellable order as AppError with ORDER_NOT_CANCELLABLE', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Order can only be cancelled while PENDING',
        errorCode: 'ORDER_NOT_CANCELLABLE',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.updateStatus(9, { status: 'CANCELLED' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 409,
      errorCode: 'ORDER_NOT_CANCELLABLE',
    });
  });

  it('surfaces a forbidden transition as AppError with ORDER_INVALID_STATUS_TRANSITION', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'Order status transition is not allowed',
        errorCode: 'ORDER_INVALID_STATUS_TRANSITION',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.updateStatus(9, { status: 'DELIVERED' });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 409,
      errorCode: 'ORDER_INVALID_STATUS_TRANSITION',
    });
  });
});

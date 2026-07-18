import type { AxiosInstance } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';
import type { PageResponse } from '@/shared/types/page-response';

import type { AdminOrderDetailResponse } from '../models/admin-order-detail-response';
import type { AdminOrderSummaryResponse } from '../models/admin-order-summary-response';
import type { OrderStatus } from '../models/order-status';
import type { UpdateOrderStatusRequest } from '../models/update-order-status-request';

const ADMIN_ORDERS_PATH = '/api/v1/admin/orders';
const ORDERS_PATH = '/api/v1/orders';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/** Optional server-driven paging, status filter, and order-code search for {@link OrderRepository.list}. */
export interface ListOrdersParams {
  readonly page?: number;
  readonly size?: number;
  readonly status?: OrderStatus;
  readonly orderCode?: string;
}

/**
 * The typed client of the two ADMIN order read endpoints plus the frozen
 * status-transition endpoint (dto-spec §20, sprint-12-plan Task 03) — the
 * React analog of the Flutter order repository (react-guidelines §Repository
 * Contract). Mirrors `ProductRepository` (Sprint 11) verbatim; there is no
 * create / update / delete method — orders are not admin-CRUD (sprint-12-plan
 * Design Decision 4).
 *
 * It only calls the API, unwraps the [ApiResponse] envelope, and returns the
 * typed payload — throwing [AppError] on failure (the single Axios instance's
 * error interceptor has already mapped the transport error). It holds no
 * business logic, no feature state, and touches no storage or navigation.
 */
export class OrderRepository {
  constructor(private readonly client: AxiosInstance) {}

  /**
   * `GET /admin/orders` — a page of orders for ADMIN management,
   * most-recent-first, optionally filtered by `status` and/or searched by an
   * `orderCode` fragment. Both are omitted from the request entirely when
   * unset — a blank `orderCode` is treated as unset, so the server never
   * receives a literal `orderCode=`.
   */
  async list(params?: ListOrdersParams): Promise<PageResponse<AdminOrderSummaryResponse>> {
    const orderCode =
      params?.orderCode !== undefined && params.orderCode.length > 0 ? params.orderCode : undefined;
    const response = await this.client.get<ApiResponse<PageResponse<AdminOrderSummaryResponse>>>(
      ADMIN_ORDERS_PATH,
      { params: { page: params?.page, size: params?.size, status: params?.status, orderCode } },
    );
    return this.unwrap(response.data.data);
  }

  /** `GET /admin/orders/{id}` — the full ADMIN detail of an order, regardless of owner. */
  async get(id: number): Promise<AdminOrderDetailResponse> {
    const response = await this.client.get<ApiResponse<AdminOrderDetailResponse>>(
      `${ADMIN_ORDERS_PATH}/${id}`,
    );
    return this.unwrap(response.data.data);
  }

  /**
   * `PATCH /orders/{id}/status` — advances an order's status. The frozen
   * ADMIN endpoint lives under the customer order path, not `/admin/orders`
   * — the read and write surfaces have different prefixes and this method
   * must not "tidy" that (sprint-12-plan Task 03).
   */
  async updateStatus(
    id: number,
    request: UpdateOrderStatusRequest,
  ): Promise<AdminOrderDetailResponse> {
    const response = await this.client.patch<ApiResponse<AdminOrderDetailResponse>>(
      `${ORDERS_PATH}/${id}/status`,
      request,
    );
    return this.unwrap(response.data.data);
  }

  private unwrap<T>(data: T | null | undefined): T {
    if (data === undefined || data === null) {
      throw new AppError({ message: UNEXPECTED_MESSAGE });
    }
    return data;
  }
}

import type { AxiosInstance, AxiosResponse } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';
import type { PageResponse } from '@/shared/types/page-response';

import type { CouponResponse } from '../models/coupon-response';
import type { CreateCouponRequest } from '../models/create-coupon-request';
import type { UpdateCouponRequest } from '../models/update-coupon-request';

const COUPONS_PATH = '/api/v1/coupons';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/** Optional server-driven paging for {@link CouponRepository.list}. */
export interface ListCouponsParams {
  readonly page?: number;
  readonly size?: number;
}

/**
 * The typed client of the three frozen ADMIN coupon endpoints (dto-spec §20)
 * — the React analog of the Flutter coupon repository (react-guidelines
 * §Repository Contract). Mirrors `BrandRepository` (Sprint 10) verbatim; the
 * only new shape is the paginated `list` (mirroring `ProductRepository`,
 * Sprint 11 Task 02) — coupons have no delete.
 *
 * It only calls the API, unwraps the [ApiResponse] envelope, and returns the
 * typed payload — throwing [AppError] on failure (the single Axios instance's
 * error interceptor has already mapped the transport error). It holds no
 * business logic, no feature state, and touches no storage or navigation.
 */
export class CouponRepository {
  constructor(private readonly client: AxiosInstance) {}

  /** `GET /coupons` — a page of coupons. */
  async list(params?: ListCouponsParams): Promise<PageResponse<CouponResponse>> {
    const response = await this.client.get<ApiResponse<PageResponse<CouponResponse>>>(
      COUPONS_PATH,
      { params },
    );
    return this.unwrap(response.data.data);
  }

  /** `POST /coupons` — create a coupon. */
  create(request: CreateCouponRequest): Promise<CouponResponse> {
    return this.write(this.client.post<ApiResponse<CouponResponse>>(COUPONS_PATH, request));
  }

  /** `PUT /coupons/{id}` — fully update a coupon. */
  update(id: number, request: UpdateCouponRequest): Promise<CouponResponse> {
    return this.write(
      this.client.put<ApiResponse<CouponResponse>>(`${COUPONS_PATH}/${id}`, request),
    );
  }

  private async write(
    request: Promise<AxiosResponse<ApiResponse<CouponResponse>>>,
  ): Promise<CouponResponse> {
    const response = await request;
    return this.unwrap(response.data.data);
  }

  private unwrap<T>(data: T | null | undefined): T {
    if (data === undefined || data === null) {
      throw new AppError({ message: UNEXPECTED_MESSAGE });
    }
    return data;
  }
}

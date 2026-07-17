import type { AxiosInstance, AxiosResponse } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

import type { BrandResponse } from '../models/brand-response';
import type { CreateBrandRequest } from '../models/create-brand-request';
import type { UpdateBrandRequest } from '../models/update-brand-request';

const BRANDS_PATH = '/api/v1/brands';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/**
 * The typed client of the four frozen brand endpoints (dto-spec §20) — the React
 * analog of the Flutter `AddressRepository` (react-guidelines §Repository
 * Contract).
 *
 * It only calls the API, unwraps the [ApiResponse] envelope, and returns the
 * typed payload — throwing [AppError] on failure (the single Axios instance's
 * error interceptor has already mapped the transport error). It holds no
 * business logic, no feature state, and touches no storage or navigation.
 */
export class BrandRepository {
  constructor(private readonly client: AxiosInstance) {}

  /** `GET /brands` — every brand. */
  async list(): Promise<BrandResponse[]> {
    const response = await this.client.get<ApiResponse<BrandResponse[]>>(BRANDS_PATH);
    return response.data.data ?? [];
  }

  /** `POST /brands` — create a brand. */
  create(request: CreateBrandRequest): Promise<BrandResponse> {
    return this.write(this.client.post<ApiResponse<BrandResponse>>(BRANDS_PATH, request));
  }

  /** `PUT /brands/{id}` — fully update a brand. */
  update(id: number, request: UpdateBrandRequest): Promise<BrandResponse> {
    return this.write(this.client.put<ApiResponse<BrandResponse>>(`${BRANDS_PATH}/${id}`, request));
  }

  /** `DELETE /brands/{id}` — delete a brand. */
  async remove(id: number): Promise<void> {
    await this.client.delete<ApiResponse<void>>(`${BRANDS_PATH}/${id}`);
  }

  private async write(
    request: Promise<AxiosResponse<ApiResponse<BrandResponse>>>,
  ): Promise<BrandResponse> {
    const response = await request;
    const data = response.data.data;
    if (data === undefined || data === null) {
      throw new AppError({ message: UNEXPECTED_MESSAGE });
    }
    return data;
  }
}

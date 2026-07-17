import type { AxiosInstance, AxiosResponse } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';

import type { CategoryResponse } from '../models/category-response';
import type { CreateCategoryRequest } from '../models/create-category-request';
import type { UpdateCategoryRequest } from '../models/update-category-request';

const CATEGORIES_PATH = '/api/v1/categories';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/**
 * The typed client of the four frozen category endpoints (dto-spec §20) — the
 * React analog of the Flutter `AddressRepository` (react-guidelines §Repository
 * Contract). Mirrors `BrandRepository` (Task 04) verbatim for the category
 * domain.
 *
 * It only calls the API, unwraps the [ApiResponse] envelope, and returns the
 * typed payload — throwing [AppError] on failure (the single Axios instance's
 * error interceptor has already mapped the transport error). It holds no
 * business logic, no feature state, and touches no storage or navigation.
 */
export class CategoryRepository {
  constructor(private readonly client: AxiosInstance) {}

  /** `GET /categories` — every category. */
  async list(): Promise<CategoryResponse[]> {
    const response = await this.client.get<ApiResponse<CategoryResponse[]>>(CATEGORIES_PATH);
    return response.data.data ?? [];
  }

  /** `POST /categories` — create a category. */
  create(request: CreateCategoryRequest): Promise<CategoryResponse> {
    return this.write(this.client.post<ApiResponse<CategoryResponse>>(CATEGORIES_PATH, request));
  }

  /** `PUT /categories/{id}` — fully update a category. */
  update(id: number, request: UpdateCategoryRequest): Promise<CategoryResponse> {
    return this.write(
      this.client.put<ApiResponse<CategoryResponse>>(`${CATEGORIES_PATH}/${id}`, request),
    );
  }

  /** `DELETE /categories/{id}` — delete a category. */
  async remove(id: number): Promise<void> {
    await this.client.delete<ApiResponse<void>>(`${CATEGORIES_PATH}/${id}`);
  }

  private async write(
    request: Promise<AxiosResponse<ApiResponse<CategoryResponse>>>,
  ): Promise<CategoryResponse> {
    const response = await request;
    const data = response.data.data;
    if (data === undefined || data === null) {
      throw new AppError({ message: UNEXPECTED_MESSAGE });
    }
    return data;
  }
}

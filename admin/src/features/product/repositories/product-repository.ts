import type { AxiosInstance, AxiosResponse } from 'axios';

import { AppError } from '@/core/error/app-error';
import type { ApiResponse } from '@/shared/types/api-response';
import type { PageResponse } from '@/shared/types/page-response';

import type { AdminProductDetailResponse } from '../models/admin-product-detail-response';
import type { AdminProductSummaryResponse } from '../models/admin-product-summary-response';
import type { CreateProductImageRequest } from '../models/create-product-image-request';
import type { CreateProductRequest } from '../models/create-product-request';
import type { CreateProductVariantRequest } from '../models/create-product-variant-request';
import type { ProductDetailResponse } from '../models/product-detail-response';
import type { ProductImageResponse } from '../models/product-image-response';
import type { ProductVariantResponse } from '../models/product-variant-response';
import type { UpdateProductImageRequest } from '../models/update-product-image-request';
import type { UpdateProductRequest } from '../models/update-product-request';
import type { UpdateProductVariantRequest } from '../models/update-product-variant-request';

const ADMIN_PRODUCTS_PATH = '/api/v1/admin/products';
const PRODUCTS_PATH = '/api/v1/products';
const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/** Optional server-driven paging for {@link ProductRepository.list}. */
export interface ListProductsParams {
  readonly page?: number;
  readonly size?: number;
}

/**
 * The typed client of the ADMIN product read endpoints (dto-spec §20) plus the
 * frozen product/variant/image write endpoints — the React analog of the
 * Flutter product repository (react-guidelines §Repository Contract). Mirrors
 * `BrandRepository` (Sprint 10) verbatim; the only new shapes are the
 * paginated ADMIN read and the nested variant/image write methods.
 *
 * It only calls the API, unwraps the [ApiResponse] envelope, and returns the
 * typed payload — throwing [AppError] on failure (the single Axios instance's
 * error interceptor has already mapped the transport error). It holds no
 * business logic, no feature state, and touches no storage or navigation.
 */
export class ProductRepository {
  constructor(private readonly client: AxiosInstance) {}

  /** `GET /admin/products` — a page of products for ADMIN management. */
  async list(params?: ListProductsParams): Promise<PageResponse<AdminProductSummaryResponse>> {
    const response = await this.client.get<ApiResponse<PageResponse<AdminProductSummaryResponse>>>(
      ADMIN_PRODUCTS_PATH,
      { params },
    );
    return this.unwrap(response.data.data);
  }

  /** `GET /admin/products/{id}` — the full ADMIN detail of a product. */
  async get(id: number): Promise<AdminProductDetailResponse> {
    const response = await this.client.get<ApiResponse<AdminProductDetailResponse>>(
      `${ADMIN_PRODUCTS_PATH}/${id}`,
    );
    return this.unwrap(response.data.data);
  }

  /** `POST /products` — create a product. */
  create(request: CreateProductRequest): Promise<ProductDetailResponse> {
    return this.write(this.client.post<ApiResponse<ProductDetailResponse>>(PRODUCTS_PATH, request));
  }

  /** `PUT /products/{id}` — fully update a product. */
  update(id: number, request: UpdateProductRequest): Promise<ProductDetailResponse> {
    return this.write(
      this.client.put<ApiResponse<ProductDetailResponse>>(`${PRODUCTS_PATH}/${id}`, request),
    );
  }

  /** `DELETE /products/{id}` — soft-delete a product. */
  async remove(id: number): Promise<void> {
    await this.client.delete<ApiResponse<void>>(`${PRODUCTS_PATH}/${id}`);
  }

  /** `POST /products/{id}/variants` — create a variant of a product. */
  createVariant(id: number, request: CreateProductVariantRequest): Promise<ProductVariantResponse> {
    return this.write(
      this.client.post<ApiResponse<ProductVariantResponse>>(
        `${PRODUCTS_PATH}/${id}/variants`,
        request,
      ),
    );
  }

  /** `PUT /products/{id}/variants/{variantId}` — update a variant of a product. */
  updateVariant(
    id: number,
    variantId: number,
    request: UpdateProductVariantRequest,
  ): Promise<ProductVariantResponse> {
    return this.write(
      this.client.put<ApiResponse<ProductVariantResponse>>(
        `${PRODUCTS_PATH}/${id}/variants/${variantId}`,
        request,
      ),
    );
  }

  /** `POST /products/{id}/images` — create an image of a product. */
  createImage(id: number, request: CreateProductImageRequest): Promise<ProductImageResponse> {
    return this.write(
      this.client.post<ApiResponse<ProductImageResponse>>(`${PRODUCTS_PATH}/${id}/images`, request),
    );
  }

  /** `PUT /products/{id}/images/{imageId}` — update an image of a product. */
  updateImage(
    id: number,
    imageId: number,
    request: UpdateProductImageRequest,
  ): Promise<ProductImageResponse> {
    return this.write(
      this.client.put<ApiResponse<ProductImageResponse>>(
        `${PRODUCTS_PATH}/${id}/images/${imageId}`,
        request,
      ),
    );
  }

  private async write<T>(request: Promise<AxiosResponse<ApiResponse<T>>>): Promise<T> {
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

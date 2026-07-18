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

import { ProductRepository } from './product-repository';
import type { AdminProductDetailResponse } from '../models/admin-product-detail-response';
import type { AdminProductSummaryResponse } from '../models/admin-product-summary-response';
import type { ProductDetailResponse } from '../models/product-detail-response';
import type { ProductImageResponse } from '../models/product-image-response';
import type { ProductVariantResponse } from '../models/product-variant-response';

const adminSummary: AdminProductSummaryResponse = {
  id: 1,
  name: 'Air Zoom',
  basePrice: 120,
  brandName: 'Nike',
  categoryName: 'Running',
  primaryImageUrl: 'https://example.com/air-zoom.png',
  averageRating: 4.5,
  available: true,
};

const adminDetail: AdminProductDetailResponse = {
  id: 1,
  name: 'Air Zoom',
  description: 'A running shoe',
  basePrice: 120,
  brandId: 10,
  brandName: 'Nike',
  categoryId: 20,
  categoryName: 'Running',
  images: [
    { id: 100, imageUrl: 'https://example.com/air-zoom.png', displayOrder: 0, isPrimary: true },
  ],
  variants: [
    {
      id: 200,
      color: 'Black',
      size: '42',
      price: 120,
      costPrice: 80,
      stockQuantity: 5,
      status: 'ACTIVE',
      sku: 'AZ-BLK-42',
    },
  ],
  averageRating: 4.5,
  reviewCount: 3,
  available: true,
  createdAt: '2026-01-01T00:00:00',
};

const productDetail: ProductDetailResponse = {
  id: 1,
  name: 'Air Zoom',
  description: 'A running shoe',
  basePrice: 120,
  brandId: 10,
  brandName: 'Nike',
  categoryId: 20,
  categoryName: 'Running',
  images: [],
  variants: [],
  averageRating: 4.5,
  reviewCount: 3,
  available: true,
  createdAt: '2026-01-01T00:00:00',
};

const variant: ProductVariantResponse = {
  id: 200,
  color: 'Black',
  size: '42',
  price: 120,
  stockQuantity: 5,
  status: 'ACTIVE',
  sku: 'AZ-BLK-42',
};

const image: ProductImageResponse = {
  id: 100,
  imageUrl: 'https://example.com/air-zoom.png',
  displayOrder: 0,
  isPrimary: true,
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

function parsedBody(config: InternalAxiosRequestConfig): unknown {
  return typeof config.data === 'string' ? JSON.parse(config.data) : config.data;
}

describe('ProductRepository', () => {
  const repository = new ProductRepository(httpClient);

  afterEach(() => {
    httpClient.defaults.adapter = undefined;
  });

  it('list issues GET /admin/products and returns the unwrapped page', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      const page: PageResponse<AdminProductSummaryResponse> = {
        content: [adminSummary],
        page: 0,
        size: 20,
        totalElements: 1,
        totalPages: 1,
        last: true,
      };
      const envelope: ApiResponse<PageResponse<AdminProductSummaryResponse>> = {
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
      url: '/api/v1/admin/products',
      params: { page: 0, size: 20 },
    });
    expect(result).toEqual({
      content: [adminSummary],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    });
  });

  it('get issues GET /admin/products/{id} and returns the unwrapped admin detail', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      const envelope: ApiResponse<AdminProductDetailResponse> = {
        success: true,
        message: 'OK',
        data: adminDetail,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.get(1);

    expect(captured).toMatchObject({ method: 'get', url: '/api/v1/admin/products/1' });
    expect(result).toEqual(adminDetail);
    expect(result.variants[0]?.costPrice).toBe(80);
  });

  it('create issues POST /products with the request body and returns the created product', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: parsedBody(config),
      };
      const envelope: ApiResponse<ProductDetailResponse> = {
        success: true,
        message: 'Created',
        data: productDetail,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.create({
      name: 'Air Zoom',
      basePrice: 120,
      categoryId: 20,
      brandId: 10,
    });

    expect(captured).toMatchObject({
      method: 'post',
      url: '/api/v1/products',
      body: { name: 'Air Zoom', basePrice: 120, categoryId: 20, brandId: 10 },
    });
    expect(result).toEqual(productDetail);
  });

  it('update issues PUT /products/{id} with the request body and returns the updated product', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: parsedBody(config),
      };
      const envelope: ApiResponse<ProductDetailResponse> = {
        success: true,
        message: 'OK',
        data: productDetail,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.update(1, {
      name: 'Air Zoom',
      basePrice: 130,
      categoryId: 20,
      brandId: 10,
    });

    expect(captured).toMatchObject({
      method: 'put',
      url: '/api/v1/products/1',
      body: { name: 'Air Zoom', basePrice: 130, categoryId: 20, brandId: 10 },
    });
    expect(result).toEqual(productDetail);
  });

  it('remove issues DELETE /products/{id}', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: config.data,
      };
      const envelope: ApiResponse<void> = {
        success: true,
        message: 'OK',
        data: null,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    await repository.remove(1);

    expect(captured).toMatchObject({ method: 'delete', url: '/api/v1/products/1' });
  });

  it('createVariant issues POST /products/{id}/variants with the full body and returns the created variant', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: parsedBody(config),
      };
      const envelope: ApiResponse<ProductVariantResponse> = {
        success: true,
        message: 'Created',
        data: variant,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.createVariant(1, {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    });

    expect(captured).toMatchObject({
      method: 'post',
      url: '/api/v1/products/1/variants',
      body: {
        color: 'Black',
        size: '42',
        stockQuantity: 5,
        sku: 'AZ-BLK-42',
        status: 'ACTIVE',
        costPrice: 80,
      },
    });
    expect(result).toEqual(variant);
  });

  it('updateVariant issues PUT /products/{id}/variants/{variantId} with the full body including costPrice', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: parsedBody(config),
      };
      const envelope: ApiResponse<ProductVariantResponse> = {
        success: true,
        message: 'OK',
        data: variant,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.updateVariant(1, 200, {
      color: 'Black',
      size: '42',
      stockQuantity: 10,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 85,
    });

    expect(captured).toMatchObject({
      method: 'put',
      url: '/api/v1/products/1/variants/200',
      body: {
        color: 'Black',
        size: '42',
        stockQuantity: 10,
        sku: 'AZ-BLK-42',
        status: 'ACTIVE',
        costPrice: 85,
      },
    });
    expect(result).toEqual(variant);
  });

  it('createImage issues POST /products/{id}/images with the request body and returns the created image', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: parsedBody(config),
      };
      const envelope: ApiResponse<ProductImageResponse> = {
        success: true,
        message: 'Created',
        data: image,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.createImage(1, {
      imageUrl: 'https://example.com/air-zoom.png',
      displayOrder: 0,
      isPrimary: true,
    });

    expect(captured).toMatchObject({
      method: 'post',
      url: '/api/v1/products/1/images',
      body: { imageUrl: 'https://example.com/air-zoom.png', displayOrder: 0, isPrimary: true },
    });
    expect(result).toEqual(image);
  });

  it('updateImage issues PUT /products/{id}/images/{imageId} with the request body and returns the updated image', async () => {
    let captured: CapturedRequest | undefined;
    httpClient.defaults.adapter = async (config) => {
      captured = {
        method: config.method,
        url: config.url,
        params: config.params,
        body: parsedBody(config),
      };
      const envelope: ApiResponse<ProductImageResponse> = {
        success: true,
        message: 'OK',
        data: image,
        timestamp: '2026-01-01T00:00:00',
      };
      return okResponse(config, envelope);
    };

    const result = await repository.updateImage(1, 100, {
      imageUrl: 'https://example.com/air-zoom-2.png',
      displayOrder: 1,
      isPrimary: false,
    });

    expect(captured).toMatchObject({
      method: 'put',
      url: '/api/v1/products/1/images/100',
      body: { imageUrl: 'https://example.com/air-zoom-2.png', displayOrder: 1, isPrimary: false },
    });
    expect(result).toEqual(image);
  });

  it('surfaces a duplicate (color, size) conflict as AppError with PRODUCT_VARIANT_DUPLICATED', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'A variant with this color and size already exists for the product',
        errorCode: 'PRODUCT_VARIANT_DUPLICATED',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.createVariant(1, {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 409,
      errorCode: 'PRODUCT_VARIANT_DUPLICATED',
    });
  });

  it('surfaces a duplicate SKU conflict as AppError with PRODUCT_VARIANT_SKU_DUPLICATED', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 409, {
        success: false,
        message: 'SKU already exists',
        errorCode: 'PRODUCT_VARIANT_SKU_DUPLICATED',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.updateVariant(1, 200, {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 409,
      errorCode: 'PRODUCT_VARIANT_SKU_DUPLICATED',
    });
  });

  it('surfaces a not-found product as AppError with PRODUCT_NOT_FOUND', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 404, {
        success: false,
        message: 'Product not found',
        errorCode: 'PRODUCT_NOT_FOUND',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.get(999);

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 404,
      errorCode: 'PRODUCT_NOT_FOUND',
    });
  });

  it('surfaces a not-found variant as AppError with PRODUCT_VARIANT_NOT_FOUND', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 404, {
        success: false,
        message: 'Product variant not found',
        errorCode: 'PRODUCT_VARIANT_NOT_FOUND',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.updateVariant(1, 999, {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 404,
      errorCode: 'PRODUCT_VARIANT_NOT_FOUND',
    });
  });

  it('surfaces a not-found image as AppError with PRODUCT_IMAGE_NOT_FOUND', async () => {
    httpClient.defaults.adapter = async (config) => {
      throw errorResponse(config, 404, {
        success: false,
        message: 'Product image not found',
        errorCode: 'PRODUCT_IMAGE_NOT_FOUND',
        timestamp: '2026-01-01T00:00:00',
      });
    };

    const promise = repository.updateImage(1, 999, {
      imageUrl: 'https://example.com/air-zoom.png',
      displayOrder: 0,
      isPrimary: true,
    });

    await expect(promise).rejects.toBeInstanceOf(AppError);
    await expect(promise).rejects.toMatchObject({
      statusCode: 404,
      errorCode: 'PRODUCT_IMAGE_NOT_FOUND',
    });
  });

  it('surfaces a non-ADMIN forbidden response on the admin read as AppError with FORBIDDEN', async () => {
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
});

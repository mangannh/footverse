import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useProductMutation } from './use-product-mutation';
import type { ProductDetailResponse } from '../models/product-detail-response';
import type { ProductImageResponse } from '../models/product-image-response';
import type { ProductVariantResponse } from '../models/product-variant-response';
import type { ProductRepository } from '../repositories/product-repository';

const productDetail: ProductDetailResponse = {
  id: 1,
  name: 'Air Zoom',
  basePrice: 120,
  brandId: 10,
  brandName: 'Nike',
  categoryId: 20,
  categoryName: 'Running',
  images: [],
  variants: [],
  averageRating: 0,
  reviewCount: 0,
  available: false,
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

function fakeRepository(overrides: Partial<ProductRepository>): ProductRepository {
  return overrides as unknown as ProductRepository;
}

describe('useProductMutation — product', () => {
  it('create succeeds and reloads', async () => {
    const repository = fakeRepository({ create: vi.fn().mockResolvedValue(productDetail) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await result.current.create({
        name: 'Air Zoom',
        basePrice: 120,
        categoryId: 20,
        brandId: 10,
      });
    });

    expect(repository.create).toHaveBeenCalledWith({
      name: 'Air Zoom',
      basePrice: 120,
      categoryId: 20,
      brandId: 10,
    });
    expect(reload).toHaveBeenCalledTimes(1);
    expect(result.current.isMutating).toBe(false);
  });

  it('update succeeds and reloads', async () => {
    const repository = fakeRepository({ update: vi.fn().mockResolvedValue(productDetail) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await result.current.update(1, {
        name: 'Air Zoom',
        basePrice: 130,
        categoryId: 20,
        brandId: 10,
      });
    });

    expect(repository.update).toHaveBeenCalledWith(1, {
      name: 'Air Zoom',
      basePrice: 130,
      categoryId: 20,
      brandId: 10,
    });
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('remove (delete) succeeds and reloads', async () => {
    const repository = fakeRepository({ remove: vi.fn().mockResolvedValue(undefined) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await result.current.remove(1);
    });

    expect(repository.remove).toHaveBeenCalledWith(1);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('rethrows an AppError on create and does not reload', async () => {
    const notFoundError = new AppError({
      message: 'Category not found',
      statusCode: 404,
      errorCode: 'CATEGORY_NOT_FOUND',
    });
    const repository = fakeRepository({ create: vi.fn().mockRejectedValue(notFoundError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await expect(
        result.current.create({ name: 'Air Zoom', basePrice: 120, categoryId: 999, brandId: 10 }),
      ).rejects.toBe(notFoundError);
    });

    expect(reload).not.toHaveBeenCalled();
    expect(result.current.isMutating).toBe(false);
  });

  it('is single-flight: a concurrent create is ignored', async () => {
    let resolveCreate: (value: ProductDetailResponse) => void = () => undefined;
    const create = vi.fn().mockImplementation(
      () =>
        new Promise<ProductDetailResponse>((resolve) => {
          resolveCreate = resolve;
        }),
    );
    const repository = fakeRepository({ create });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      const first = result.current.create({
        name: 'Air Zoom',
        basePrice: 120,
        categoryId: 20,
        brandId: 10,
      });
      const second = result.current.create({
        name: 'Air Zoom',
        basePrice: 120,
        categoryId: 20,
        brandId: 10,
      });
      resolveCreate(productDetail);
      await Promise.all([first, second]);
    });

    expect(create).toHaveBeenCalledTimes(1);
    expect(reload).toHaveBeenCalledTimes(1);
  });
});

describe('useProductMutation — variant', () => {
  it('createVariant succeeds, sends costPrice in the request, and reloads', async () => {
    const repository = fakeRepository({ createVariant: vi.fn().mockResolvedValue(variant) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await result.current.createVariant(1, {
        color: 'Black',
        size: '42',
        stockQuantity: 5,
        sku: 'AZ-BLK-42',
        status: 'ACTIVE',
        costPrice: 80,
      });
    });

    expect(repository.createVariant).toHaveBeenCalledWith(1, {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    });
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('updateVariant succeeds and reloads', async () => {
    const repository = fakeRepository({ updateVariant: vi.fn().mockResolvedValue(variant) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await result.current.updateVariant(1, 200, {
        color: 'Black',
        size: '42',
        stockQuantity: 10,
        sku: 'AZ-BLK-42',
        status: 'INACTIVE',
        costPrice: 85,
      });
    });

    expect(repository.updateVariant).toHaveBeenCalledWith(1, 200, {
      color: 'Black',
      size: '42',
      stockQuantity: 10,
      sku: 'AZ-BLK-42',
      status: 'INACTIVE',
      costPrice: 85,
    });
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('rethrows PRODUCT_VARIANT_DUPLICATED on a duplicate (color, size) and does not reload', async () => {
    const duplicateError = new AppError({
      message: 'A variant with this color and size already exists for the product',
      statusCode: 409,
      errorCode: 'PRODUCT_VARIANT_DUPLICATED',
    });
    const repository = fakeRepository({
      createVariant: vi.fn().mockRejectedValue(duplicateError),
    });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await expect(
        result.current.createVariant(1, {
          color: 'Black',
          size: '42',
          stockQuantity: 5,
          sku: 'AZ-BLK-42',
          status: 'ACTIVE',
          costPrice: 80,
        }),
      ).rejects.toBe(duplicateError);
    });

    expect(reload).not.toHaveBeenCalled();
    expect(result.current.isMutating).toBe(false);
  });

  it('rethrows PRODUCT_VARIANT_SKU_DUPLICATED on a duplicate SKU and does not reload', async () => {
    const skuDuplicateError = new AppError({
      message: 'SKU already exists',
      statusCode: 409,
      errorCode: 'PRODUCT_VARIANT_SKU_DUPLICATED',
    });
    const repository = fakeRepository({
      updateVariant: vi.fn().mockRejectedValue(skuDuplicateError),
    });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await expect(
        result.current.updateVariant(1, 200, {
          color: 'Black',
          size: '42',
          stockQuantity: 5,
          sku: 'AZ-BLK-42',
          status: 'ACTIVE',
          costPrice: 80,
        }),
      ).rejects.toBe(skuDuplicateError);
    });

    expect(reload).not.toHaveBeenCalled();
  });
});

describe('useProductMutation — image', () => {
  it('createImage succeeds and reloads so the server-decided primary is re-read', async () => {
    const repository = fakeRepository({ createImage: vi.fn().mockResolvedValue(image) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await result.current.createImage(1, {
        imageUrl: 'https://example.com/air-zoom.png',
        displayOrder: 0,
        isPrimary: true,
      });
    });

    expect(repository.createImage).toHaveBeenCalledWith(1, {
      imageUrl: 'https://example.com/air-zoom.png',
      displayOrder: 0,
      isPrimary: true,
    });
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('updateImage succeeds and reloads', async () => {
    const repository = fakeRepository({ updateImage: vi.fn().mockResolvedValue(image) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await result.current.updateImage(1, 100, {
        imageUrl: 'https://example.com/air-zoom-2.png',
        displayOrder: 1,
        isPrimary: false,
      });
    });

    expect(repository.updateImage).toHaveBeenCalledWith(1, 100, {
      imageUrl: 'https://example.com/air-zoom-2.png',
      displayOrder: 1,
      isPrimary: false,
    });
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('rethrows PRODUCT_IMAGE_NOT_FOUND and does not reload', async () => {
    const notFoundError = new AppError({
      message: 'Product image not found',
      statusCode: 404,
      errorCode: 'PRODUCT_IMAGE_NOT_FOUND',
    });
    const repository = fakeRepository({ updateImage: vi.fn().mockRejectedValue(notFoundError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useProductMutation(repository, reload));

    await act(async () => {
      await expect(
        result.current.updateImage(1, 999, {
          imageUrl: 'https://example.com/air-zoom.png',
          displayOrder: 0,
          isPrimary: true,
        }),
      ).rejects.toBe(notFoundError);
    });

    expect(reload).not.toHaveBeenCalled();
  });
});

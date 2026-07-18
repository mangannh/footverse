import { describe, expect, it } from 'vitest';

import type { AdminProductDetailResponse } from './admin-product-detail-response';
import type { AdminProductSummaryResponse } from './admin-product-summary-response';
import type { AdminProductVariantResponse } from './admin-product-variant-response';
import type { CreateProductImageRequest } from './create-product-image-request';
import type { CreateProductRequest } from './create-product-request';
import type { CreateProductVariantRequest } from './create-product-variant-request';
import type { ProductDetailResponse } from './product-detail-response';
import type { ProductImageResponse } from './product-image-response';
import type { ProductVariantResponse } from './product-variant-response';
import type { UpdateProductImageRequest } from './update-product-image-request';
import type { UpdateProductRequest } from './update-product-request';
import type { UpdateProductVariantRequest } from './update-product-variant-request';

// Captured backend payloads (dto-spec §9). Request types omit optional fields
// from the serialized JSON when unset (react-guidelines §Models); response
// types deserialize a captured payload field-for-field. `costPrice` /
// `priceOverride` are ADMIN-only (Sprint 11) — present on the ADMIN variant
// types, absent from any public-shaped type.
describe('CreateProductRequest', () => {
  it('omits description from the JSON when unset', () => {
    const request: CreateProductRequest = {
      name: 'Air Zoom',
      basePrice: 120,
      categoryId: 20,
      brandId: 10,
    };

    const json = JSON.parse(JSON.stringify(request)) as Record<string, unknown>;

    expect(json).toEqual({ name: 'Air Zoom', basePrice: 120, categoryId: 20, brandId: 10 });
    expect('description' in json).toBe(false);
  });

  it('serializes every field when all are set', () => {
    const request: CreateProductRequest = {
      name: 'Air Zoom',
      description: 'A running shoe',
      basePrice: 120,
      categoryId: 20,
      brandId: 10,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });
});

describe('UpdateProductRequest', () => {
  it('is field-for-field identical to CreateProductRequest', () => {
    const request: UpdateProductRequest = {
      name: 'Air Zoom',
      basePrice: 120,
      categoryId: 20,
      brandId: 10,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });
});

describe('CreateProductVariantRequest', () => {
  it('omits priceOverride from the JSON when unset, but always carries costPrice', () => {
    const request: CreateProductVariantRequest = {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    };

    const json = JSON.parse(JSON.stringify(request)) as Record<string, unknown>;

    expect(json).toEqual({
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    });
    expect('priceOverride' in json).toBe(false);
  });

  it('serializes every field when all are set, including priceOverride and costPrice', () => {
    const request: CreateProductVariantRequest = {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      priceOverride: 110,
      status: 'ACTIVE',
      costPrice: 80,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });
});

describe('UpdateProductVariantRequest', () => {
  it('is field-for-field identical to CreateProductVariantRequest', () => {
    const request: UpdateProductVariantRequest = {
      color: 'Black',
      size: '42',
      stockQuantity: 5,
      sku: 'AZ-BLK-42',
      status: 'ACTIVE',
      costPrice: 80,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });
});

describe('CreateProductImageRequest / UpdateProductImageRequest', () => {
  it('serializes every required field', () => {
    const request: CreateProductImageRequest = {
      imageUrl: 'https://example.com/air-zoom.png',
      displayOrder: 0,
      isPrimary: true,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });

  it('UpdateProductImageRequest is field-for-field identical to CreateProductImageRequest', () => {
    const request: UpdateProductImageRequest = {
      imageUrl: 'https://example.com/air-zoom.png',
      displayOrder: 0,
      isPrimary: true,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });
});

describe('ProductImageResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = {
      id: 100,
      imageUrl: 'https://example.com/air-zoom.png',
      displayOrder: 0,
      isPrimary: true,
    };

    const image: ProductImageResponse = JSON.parse(JSON.stringify(payload));

    expect(image).toEqual(payload);
  });
});

describe('ProductVariantResponse (public)', () => {
  it('deserializes a captured payload field-for-field and never carries costPrice or priceOverride', () => {
    const payload = {
      id: 200,
      color: 'Black',
      size: '42',
      price: 120,
      stockQuantity: 5,
      status: 'ACTIVE',
      sku: 'AZ-BLK-42',
    };

    const variant: ProductVariantResponse = JSON.parse(JSON.stringify(payload));

    expect(variant).toEqual(payload);
    expect('costPrice' in variant).toBe(false);
    expect('priceOverride' in variant).toBe(false);
  });
});

describe('ProductDetailResponse (public)', () => {
  it('deserializes a captured payload field-for-field, nesting public images and variants', () => {
    const payload = {
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

    const detail: ProductDetailResponse = JSON.parse(JSON.stringify(payload));

    expect(detail).toEqual(payload);
    expect('costPrice' in detail.variants[0]!).toBe(false);
  });

  it('deserializes a payload with the optional description omitted', () => {
    const payload = {
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

    const detail: ProductDetailResponse = JSON.parse(JSON.stringify(payload));

    expect(detail.description).toBeUndefined();
  });
});

describe('AdminProductSummaryResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = {
      id: 1,
      name: 'Air Zoom',
      basePrice: 120,
      brandName: 'Nike',
      categoryName: 'Running',
      primaryImageUrl: 'https://example.com/air-zoom.png',
      averageRating: 4.5,
      available: true,
    };

    const summary: AdminProductSummaryResponse = JSON.parse(JSON.stringify(payload));

    expect(summary).toEqual(payload);
  });

  it('deserializes a payload with the optional primaryImageUrl omitted', () => {
    const payload = {
      id: 1,
      name: 'Air Zoom',
      basePrice: 120,
      brandName: 'Nike',
      categoryName: 'Running',
      averageRating: 0,
      available: false,
    };

    const summary: AdminProductSummaryResponse = JSON.parse(JSON.stringify(payload));

    expect(summary.primaryImageUrl).toBeUndefined();
  });
});

describe('AdminProductVariantResponse', () => {
  it('deserializes a captured payload carrying the ADMIN-only costPrice and priceOverride', () => {
    const payload = {
      id: 200,
      color: 'Black',
      size: '42',
      price: 110,
      priceOverride: 110,
      costPrice: 80,
      stockQuantity: 5,
      status: 'ACTIVE',
      sku: 'AZ-BLK-42',
    };

    const variant: AdminProductVariantResponse = JSON.parse(JSON.stringify(payload));

    expect(variant).toEqual(payload);
    expect(variant.costPrice).toBe(80);
    expect(variant.priceOverride).toBe(110);
  });

  it('deserializes a payload where priceOverride is null (the variant follows basePrice), costPrice still present', () => {
    const payload = {
      id: 200,
      color: 'Black',
      size: '42',
      price: 120,
      priceOverride: null,
      costPrice: 80,
      stockQuantity: 5,
      status: 'ACTIVE',
      sku: 'AZ-BLK-42',
    };

    const variant: AdminProductVariantResponse = JSON.parse(JSON.stringify(payload));

    expect(variant.priceOverride).toBeNull();
    expect(variant.costPrice).toBe(80);
  });
});

describe('AdminProductDetailResponse', () => {
  it('deserializes a captured payload, nesting ADMIN variants (with costPrice) and public images', () => {
    const payload = {
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
          priceOverride: null,
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

    const detail: AdminProductDetailResponse = JSON.parse(JSON.stringify(payload));

    expect(detail).toEqual(payload);
    expect(detail.variants[0]?.costPrice).toBe(80);
  });
});

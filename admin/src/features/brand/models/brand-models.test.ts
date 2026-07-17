import { describe, expect, it } from 'vitest';

import type { BrandResponse } from './brand-response';
import type { CreateBrandRequest } from './create-brand-request';
import type { UpdateBrandRequest } from './update-brand-request';

// Captured backend payloads (dto-spec §11). Request types omit `logoUrl` /
// `description` from the serialized JSON when unset (react-guidelines
// §Models); `BrandResponse` deserializes a captured payload field-for-field.
describe('CreateBrandRequest', () => {
  it('omits logoUrl and description from the JSON when unset', () => {
    const request: CreateBrandRequest = { name: 'Nike' };

    const json = JSON.parse(JSON.stringify(request)) as Record<string, unknown>;

    expect(json).toEqual({ name: 'Nike' });
    expect('logoUrl' in json).toBe(false);
    expect('description' in json).toBe(false);
  });

  it('serializes every field when all are set', () => {
    const request: CreateBrandRequest = {
      name: 'Nike',
      logoUrl: 'https://example.com/nike.png',
      description: 'Sportswear',
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual({
      name: 'Nike',
      logoUrl: 'https://example.com/nike.png',
      description: 'Sportswear',
    });
  });
});

describe('UpdateBrandRequest', () => {
  it('is field-for-field identical to CreateBrandRequest', () => {
    const request: UpdateBrandRequest = { name: 'Nike' };

    expect(JSON.parse(JSON.stringify(request))).toEqual({ name: 'Nike' });
  });
});

describe('BrandResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = {
      id: 1,
      name: 'Nike',
      logoUrl: 'https://example.com/nike.png',
      description: 'Sportswear',
    };

    const brand: BrandResponse = JSON.parse(JSON.stringify(payload));

    expect(brand).toEqual(payload);
  });

  it('deserializes a payload with the optional fields omitted', () => {
    const payload = { id: 1, name: 'Nike' };

    const brand: BrandResponse = JSON.parse(JSON.stringify(payload));

    expect(brand.logoUrl).toBeUndefined();
    expect(brand.description).toBeUndefined();
  });
});

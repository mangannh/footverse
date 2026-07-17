import { describe, expect, it } from 'vitest';

import type { CategoryResponse } from './category-response';
import type { CreateCategoryRequest } from './create-category-request';
import type { UpdateCategoryRequest } from './update-category-request';

// Captured backend payloads (dto-spec §10). Request types omit `description`
// from the serialized JSON when unset (react-guidelines §Models); category has
// no `logoUrl` — `CategoryResponse` deserializes a captured payload
// field-for-field.
describe('CreateCategoryRequest', () => {
  it('omits description from the JSON when unset', () => {
    const request: CreateCategoryRequest = { name: 'Running Shoes' };

    const json = JSON.parse(JSON.stringify(request)) as Record<string, unknown>;

    expect(json).toEqual({ name: 'Running Shoes' });
    expect('description' in json).toBe(false);
  });

  it('serializes every field when set', () => {
    const request: CreateCategoryRequest = {
      name: 'Running Shoes',
      description: 'Shoes built for running',
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual({
      name: 'Running Shoes',
      description: 'Shoes built for running',
    });
  });
});

describe('UpdateCategoryRequest', () => {
  it('is field-for-field identical to CreateCategoryRequest', () => {
    const request: UpdateCategoryRequest = { name: 'Running Shoes' };

    expect(JSON.parse(JSON.stringify(request))).toEqual({ name: 'Running Shoes' });
  });
});

describe('CategoryResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = { id: 1, name: 'Running Shoes', description: 'Shoes built for running' };

    const category: CategoryResponse = JSON.parse(JSON.stringify(payload));

    expect(category).toEqual(payload);
  });

  it('deserializes a payload with the optional description omitted', () => {
    const payload = { id: 1, name: 'Running Shoes' };

    const category: CategoryResponse = JSON.parse(JSON.stringify(payload));

    expect(category.description).toBeUndefined();
  });
});

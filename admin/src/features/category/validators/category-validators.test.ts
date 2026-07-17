import { describe, expect, it } from 'vitest';

import { categoryValidators } from './category-validators';

describe('categoryValidators.name', () => {
  it('accepts a non-blank name', () => {
    expect(categoryValidators.name('Running Shoes')).toBeUndefined();
  });

  it('rejects a blank name', () => {
    expect(categoryValidators.name('   ')).toBe('Name is required');
  });
});

describe('categoryValidators.description', () => {
  it('accepts an empty value (optional field)', () => {
    expect(categoryValidators.description('')).toBeUndefined();
  });

  it('accepts a value at the 2000-character limit', () => {
    expect(categoryValidators.description('a'.repeat(2000))).toBeUndefined();
  });

  it('rejects a value over the 2000-character limit', () => {
    expect(categoryValidators.description('a'.repeat(2001))).toBe(
      'Description must be at most 2000 characters',
    );
  });
});

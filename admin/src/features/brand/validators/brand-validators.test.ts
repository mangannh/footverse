import { describe, expect, it } from 'vitest';

import { brandValidators } from './brand-validators';

describe('brandValidators.name', () => {
  it('accepts a non-blank name', () => {
    expect(brandValidators.name('Nike')).toBeUndefined();
  });

  it('rejects a blank name', () => {
    expect(brandValidators.name('   ')).toBe('Name is required');
  });
});

describe('brandValidators.logoUrl', () => {
  it('accepts an empty value (optional field)', () => {
    expect(brandValidators.logoUrl('')).toBeUndefined();
  });

  it('accepts a value at the 512-character limit', () => {
    expect(brandValidators.logoUrl('a'.repeat(512))).toBeUndefined();
  });

  it('rejects a value over the 512-character limit', () => {
    expect(brandValidators.logoUrl('a'.repeat(513))).toBe(
      'Logo URL must be at most 512 characters',
    );
  });
});

describe('brandValidators.description', () => {
  it('accepts an empty value (optional field)', () => {
    expect(brandValidators.description('')).toBeUndefined();
  });

  it('accepts a value at the 2000-character limit', () => {
    expect(brandValidators.description('a'.repeat(2000))).toBeUndefined();
  });

  it('rejects a value over the 2000-character limit', () => {
    expect(brandValidators.description('a'.repeat(2001))).toBe(
      'Description must be at most 2000 characters',
    );
  });
});

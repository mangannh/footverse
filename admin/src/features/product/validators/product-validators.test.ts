import { describe, expect, it } from 'vitest';

import {
  productImageValidators,
  productValidators,
  productVariantValidators,
} from './product-validators';

describe('productValidators.name', () => {
  it('accepts a non-blank name', () => {
    expect(productValidators.name('Air Zoom')).toBeUndefined();
  });

  it('rejects a blank name', () => {
    expect(productValidators.name('   ')).toBe('Name is required');
  });
});

describe('productValidators.description', () => {
  it('accepts an empty value (optional field)', () => {
    expect(productValidators.description('')).toBeUndefined();
  });

  it('accepts a value at the 2000-character limit', () => {
    expect(productValidators.description('a'.repeat(2000))).toBeUndefined();
  });

  it('rejects a value over the 2000-character limit', () => {
    expect(productValidators.description('a'.repeat(2001))).toBe(
      'Description must be at most 2000 characters',
    );
  });
});

describe('productValidators.basePrice', () => {
  it('accepts a positive value', () => {
    expect(productValidators.basePrice('120')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(productValidators.basePrice('')).toBe('Base price is required');
  });

  it('rejects zero', () => {
    expect(productValidators.basePrice('0')).toBe('Base price must be greater than 0');
  });

  it('rejects a negative value', () => {
    expect(productValidators.basePrice('-1')).toBe('Base price must be greater than 0');
  });

  it('rejects a non-numeric value', () => {
    expect(productValidators.basePrice('abc')).toBe('Base price must be greater than 0');
  });
});

describe('productValidators.categoryId', () => {
  it('accepts a selected category', () => {
    expect(productValidators.categoryId('20')).toBeUndefined();
  });

  it('rejects an unselected category', () => {
    expect(productValidators.categoryId('')).toBe('Category is required');
  });
});

describe('productValidators.brandId', () => {
  it('accepts a selected brand', () => {
    expect(productValidators.brandId('10')).toBeUndefined();
  });

  it('rejects an unselected brand', () => {
    expect(productValidators.brandId('')).toBe('Brand is required');
  });
});

describe('productVariantValidators.color', () => {
  it('accepts a non-blank color within the length limit', () => {
    expect(productVariantValidators.color('Black')).toBeUndefined();
  });

  it('rejects a blank color', () => {
    expect(productVariantValidators.color('')).toBe('Color is required');
  });

  it('accepts a value at the 50-character limit', () => {
    expect(productVariantValidators.color('a'.repeat(50))).toBeUndefined();
  });

  it('rejects a value over the 50-character limit', () => {
    expect(productVariantValidators.color('a'.repeat(51))).toBe(
      'Color must be at most 50 characters',
    );
  });
});

describe('productVariantValidators.size', () => {
  it('accepts a non-blank size', () => {
    expect(productVariantValidators.size('42')).toBeUndefined();
  });

  it('rejects a blank size', () => {
    expect(productVariantValidators.size('')).toBe('Size is required');
  });
});

describe('productVariantValidators.sku', () => {
  it('accepts a non-blank SKU', () => {
    expect(productVariantValidators.sku('AZ-BLK-42')).toBeUndefined();
  });

  it('rejects a blank SKU', () => {
    expect(productVariantValidators.sku('')).toBe('SKU is required');
  });
});

describe('productVariantValidators.stockQuantity', () => {
  it('accepts zero', () => {
    expect(productVariantValidators.stockQuantity('0')).toBeUndefined();
  });

  it('accepts a positive integer', () => {
    expect(productVariantValidators.stockQuantity('5')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(productVariantValidators.stockQuantity('')).toBe('Stock quantity is required');
  });

  it('rejects a negative value', () => {
    expect(productVariantValidators.stockQuantity('-1')).toBe(
      'Stock quantity must be zero or more',
    );
  });
});

describe('productVariantValidators.priceOverride', () => {
  it('accepts an empty value (optional field)', () => {
    expect(productVariantValidators.priceOverride('')).toBeUndefined();
  });

  it('accepts a positive value', () => {
    expect(productVariantValidators.priceOverride('99.99')).toBeUndefined();
  });

  it('rejects zero', () => {
    expect(productVariantValidators.priceOverride('0')).toBe(
      'Price override must be greater than 0',
    );
  });
});

describe('productVariantValidators.costPrice', () => {
  it('accepts zero', () => {
    expect(productVariantValidators.costPrice('0')).toBeUndefined();
  });

  it('accepts a positive value', () => {
    expect(productVariantValidators.costPrice('80')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(productVariantValidators.costPrice('')).toBe('Cost price is required');
  });

  it('rejects a negative value', () => {
    expect(productVariantValidators.costPrice('-1')).toBe('Cost price must be zero or more');
  });
});

describe('productImageValidators.imageUrl', () => {
  it('accepts a non-blank URL within the length limit', () => {
    expect(productImageValidators.imageUrl('https://example.com/a.png')).toBeUndefined();
  });

  it('rejects a blank URL', () => {
    expect(productImageValidators.imageUrl('')).toBe('Image URL is required');
  });

  it('accepts a value at the 512-character limit', () => {
    expect(productImageValidators.imageUrl('a'.repeat(512))).toBeUndefined();
  });

  it('rejects a value over the 512-character limit', () => {
    expect(productImageValidators.imageUrl('a'.repeat(513))).toBe(
      'Image URL must be at most 512 characters',
    );
  });
});

describe('productImageValidators.displayOrder', () => {
  it('accepts zero', () => {
    expect(productImageValidators.displayOrder('0')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(productImageValidators.displayOrder('')).toBe('Display order is required');
  });

  it('rejects a negative value', () => {
    expect(productImageValidators.displayOrder('-1')).toBe('Display order must be zero or more');
  });
});

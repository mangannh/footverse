// Frozen product / variant / image constraints (validation-spec §12). A
// pre-submit check never rejects input the server would accept. Messages
// live here as the single source, never inline in a component.
const NAME_REQUIRED = 'Name is required';
const DESCRIPTION_MAX_LENGTH = 2000;
const DESCRIPTION_TOO_LONG = `Description must be at most ${DESCRIPTION_MAX_LENGTH} characters`;
const BASE_PRICE_REQUIRED = 'Base price is required';
const BASE_PRICE_MUST_BE_POSITIVE = 'Base price must be greater than 0';
const CATEGORY_REQUIRED = 'Category is required';
const BRAND_REQUIRED = 'Brand is required';

const COLOR_REQUIRED = 'Color is required';
const COLOR_MAX_LENGTH = 50;
const COLOR_TOO_LONG = `Color must be at most ${COLOR_MAX_LENGTH} characters`;
const SIZE_REQUIRED = 'Size is required';
const SKU_REQUIRED = 'SKU is required';
const STOCK_QUANTITY_REQUIRED = 'Stock quantity is required';
const STOCK_QUANTITY_MUST_NOT_BE_NEGATIVE = 'Stock quantity must be zero or more';
const PRICE_OVERRIDE_MUST_BE_POSITIVE = 'Price override must be greater than 0';
const COST_PRICE_REQUIRED = 'Cost price is required';
const COST_PRICE_MUST_NOT_BE_NEGATIVE = 'Cost price must be zero or more';

const IMAGE_URL_REQUIRED = 'Image URL is required';
const IMAGE_URL_MAX_LENGTH = 512;
const IMAGE_URL_TOO_LONG = `Image URL must be at most ${IMAGE_URL_MAX_LENGTH} characters`;
const DISPLAY_ORDER_REQUIRED = 'Display order is required';
const DISPLAY_ORDER_MUST_NOT_BE_NEGATIVE = 'Display order must be zero or more';

/** Field validators for the product-core form (`CreateProductRequest` / `UpdateProductRequest`). */
export const productValidators = {
  /** `@NotBlank` — required product name. */
  name(value: string): string | undefined {
    if (value.trim().length === 0) {
      return NAME_REQUIRED;
    }
    return undefined;
  },

  /** `@Size(max=2000)` — optional description. */
  description(value: string): string | undefined {
    if (value.length > DESCRIPTION_MAX_LENGTH) {
      return DESCRIPTION_TOO_LONG;
    }
    return undefined;
  },

  /** `@NotNull @Positive` — required, strictly positive base price. */
  basePrice(value: string): string | undefined {
    if (value.trim().length === 0) {
      return BASE_PRICE_REQUIRED;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return BASE_PRICE_MUST_BE_POSITIVE;
    }
    return undefined;
  },

  /** `@NotNull @Positive` — required category. */
  categoryId(value: string): string | undefined {
    if (value.trim().length === 0) {
      return CATEGORY_REQUIRED;
    }
    return undefined;
  },

  /** `@NotNull @Positive` — required brand. */
  brandId(value: string): string | undefined {
    if (value.trim().length === 0) {
      return BRAND_REQUIRED;
    }
    return undefined;
  },
};

/**
 * Field validators for the variant form (`CreateProductVariantRequest` /
 * `UpdateProductVariantRequest`). `(color, size)` uniqueness and SKU
 * uniqueness are server-authoritative — never re-implemented here.
 */
export const productVariantValidators = {
  /** `@NotBlank @Size(max=50)` — required color. */
  color(value: string): string | undefined {
    if (value.trim().length === 0) {
      return COLOR_REQUIRED;
    }
    if (value.length > COLOR_MAX_LENGTH) {
      return COLOR_TOO_LONG;
    }
    return undefined;
  },

  /** `@NotBlank` — required size. */
  size(value: string): string | undefined {
    if (value.trim().length === 0) {
      return SIZE_REQUIRED;
    }
    return undefined;
  },

  /** `@NotBlank` — required, unique SKU. */
  sku(value: string): string | undefined {
    if (value.trim().length === 0) {
      return SKU_REQUIRED;
    }
    return undefined;
  },

  /** `@NotNull @Min(0)` — required, zero or positive stock. */
  stockQuantity(value: string): string | undefined {
    if (value.trim().length === 0) {
      return STOCK_QUANTITY_REQUIRED;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || !Number.isInteger(parsed) || parsed < 0) {
      return STOCK_QUANTITY_MUST_NOT_BE_NEGATIVE;
    }
    return undefined;
  },

  /** `@Positive` — optional; when blank the base price applies. */
  priceOverride(value: string): string | undefined {
    if (value.trim().length === 0) {
      return undefined;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return PRICE_OVERRIDE_MUST_BE_POSITIVE;
    }
    return undefined;
  },

  /** `@NotNull @PositiveOrZero` — required, zero or positive unit cost. */
  costPrice(value: string): string | undefined {
    if (value.trim().length === 0) {
      return COST_PRICE_REQUIRED;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || parsed < 0) {
      return COST_PRICE_MUST_NOT_BE_NEGATIVE;
    }
    return undefined;
  },
};

/** Field validators for the image form (`CreateProductImageRequest` / `UpdateProductImageRequest`). */
export const productImageValidators = {
  /** `@NotBlank @Size(max=512)` — required image URL. */
  imageUrl(value: string): string | undefined {
    if (value.trim().length === 0) {
      return IMAGE_URL_REQUIRED;
    }
    if (value.length > IMAGE_URL_MAX_LENGTH) {
      return IMAGE_URL_TOO_LONG;
    }
    return undefined;
  },

  /** `@NotNull @Min(0)` — required, zero or positive display order. */
  displayOrder(value: string): string | undefined {
    if (value.trim().length === 0) {
      return DISPLAY_ORDER_REQUIRED;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || !Number.isInteger(parsed) || parsed < 0) {
      return DISPLAY_ORDER_MUST_NOT_BE_NEGATIVE;
    }
    return undefined;
  },
};

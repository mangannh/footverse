// Frozen coupon constraints (validation-spec §12). A pre-submit check never
// rejects input the server would accept. Messages live here as the single
// source, never inline in a component. The `endAt > startAt` window and code
// uniqueness are server-authoritative business rules (COUPON_INVALID_DATE_RANGE
// / COUPON_CODE_DUPLICATED) and are never re-implemented here — the client
// only mirrors the field-level `@NotBlank` / `@Size` / `@Positive` constraints.
const CODE_REQUIRED = 'Code is required';
const CODE_MAX_LENGTH = 64;
const CODE_TOO_LONG = `Code must be at most ${CODE_MAX_LENGTH} characters`;
const NAME_REQUIRED = 'Name is required';
const DESCRIPTION_MAX_LENGTH = 2000;
const DESCRIPTION_TOO_LONG = `Description must be at most ${DESCRIPTION_MAX_LENGTH} characters`;
const DISCOUNT_VALUE_REQUIRED = 'Discount value is required';
const DISCOUNT_VALUE_MUST_BE_POSITIVE = 'Discount value must be greater than 0';
const MIN_ORDER_AMOUNT_REQUIRED = 'Minimum order amount is required';
const MIN_ORDER_AMOUNT_MUST_NOT_BE_NEGATIVE = 'Minimum order amount must be zero or more';
const MAX_DISCOUNT_AMOUNT_MUST_BE_POSITIVE = 'Maximum discount amount must be greater than 0';
const START_AT_REQUIRED = 'Start date is required';
const END_AT_REQUIRED = 'End date is required';
const USAGE_LIMIT_MUST_BE_POSITIVE = 'Usage limit must be greater than 0';

/** Field validators for the coupon form (`CreateCouponRequest` / `UpdateCouponRequest`). */
export const couponValidators = {
  /** `@NotBlank @Size(max=64)` — required, unique code. */
  code(value: string): string | undefined {
    if (value.trim().length === 0) {
      return CODE_REQUIRED;
    }
    if (value.length > CODE_MAX_LENGTH) {
      return CODE_TOO_LONG;
    }
    return undefined;
  },

  /** `@NotBlank` — required name. */
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

  /** `@NotNull @Positive` — required, strictly positive discount value. */
  discountValue(value: string): string | undefined {
    if (value.trim().length === 0) {
      return DISCOUNT_VALUE_REQUIRED;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return DISCOUNT_VALUE_MUST_BE_POSITIVE;
    }
    return undefined;
  },

  /** `@NotNull @PositiveOrZero` — required, zero or positive minimum order amount. */
  minOrderAmount(value: string): string | undefined {
    if (value.trim().length === 0) {
      return MIN_ORDER_AMOUNT_REQUIRED;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || parsed < 0) {
      return MIN_ORDER_AMOUNT_MUST_NOT_BE_NEGATIVE;
    }
    return undefined;
  },

  /** `@Positive` — optional cap; strictly positive when present. */
  maxDiscountAmount(value: string): string | undefined {
    if (value.trim().length === 0) {
      return undefined;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return MAX_DISCOUNT_AMOUNT_MUST_BE_POSITIVE;
    }
    return undefined;
  },

  /** `@NotNull` — required validity start. Never compared against `endAt` (server-authoritative). */
  startAt(value: string): string | undefined {
    if (value.trim().length === 0) {
      return START_AT_REQUIRED;
    }
    return undefined;
  },

  /** `@NotNull` — required validity end. Never compared against `startAt` (server-authoritative). */
  endAt(value: string): string | undefined {
    if (value.trim().length === 0) {
      return END_AT_REQUIRED;
    }
    return undefined;
  },

  /** `@Positive` — optional global usage cap; strictly positive when present. */
  usageLimit(value: string): string | undefined {
    if (value.trim().length === 0) {
      return undefined;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || !Number.isInteger(parsed) || parsed <= 0) {
      return USAGE_LIMIT_MUST_BE_POSITIVE;
    }
    return undefined;
  },
};

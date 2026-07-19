/**
 * One row of the ADMIN dashboard's best-selling products (dto-spec §15,
 * Sprint 13), folded server-side from per-variant sales up to product level.
 * Mirrors the frozen DTO field-for-field.
 *
 * `productImageUrl` is optional (`String`) on the backend record with no
 * `@JsonInclude(NON_NULL)`, so Jackson's default inclusion serializes an
 * unset value as an explicit JSON `null` rather than omitting the key — the
 * response can carry `null`, not only `undefined` (the Sprint 11
 * `CouponResponse` precedent, mirrored by the `order` feature's
 * `OrderItemResponse.productImageUrl`).
 */
export interface BestSellingProductResponse {
  readonly productId: number;
  readonly productName: string;
  readonly productImageUrl?: string | null;
  readonly quantitySold: number;
  readonly revenue: number;
}

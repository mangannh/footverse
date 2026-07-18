/**
 * One line of an order, with its checkout snapshots (dto-spec §15). Reused
 * unchanged by the ADMIN order detail — order lines carry nothing that needs
 * isolating from ADMIN. Mirrors the frozen DTO field-for-field.
 *
 * `productImageUrl` is optional (`String`) on the backend record with no
 * `@JsonInclude(NON_NULL)`, so Jackson's default inclusion serializes an
 * unset value as an explicit JSON `null` rather than omitting the key — the
 * response can carry `null`, not only `undefined` (the Sprint 11
 * `CouponResponse` precedent).
 */
export interface OrderItemResponse {
  readonly id: number;
  readonly productVariantId: number;
  readonly productId: number;
  readonly productName: string;
  readonly productImageUrl?: string | null;
  readonly color: string;
  readonly size: string;
  readonly unitPrice: number;
  readonly quantity: number;
  readonly lineTotal: number;
}

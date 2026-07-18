/**
 * A compact product for the ADMIN management list (dto-spec §9,
 * `GET /admin/products`). A dedicated ADMIN DTO — never reused for the public
 * catalog read. Mirrors the frozen DTO field-for-field.
 */
export interface AdminProductSummaryResponse {
  readonly id: number;
  readonly name: string;
  readonly basePrice: number;
  readonly brandName: string;
  readonly categoryName: string;
  readonly primaryImageUrl?: string;
  readonly averageRating: number;
  readonly available: boolean;
}

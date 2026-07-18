/** A product image (dto-spec §9). Mirrors the frozen DTO field-for-field. */
export interface ProductImageResponse {
  readonly id: number;
  readonly imageUrl: string;
  readonly displayOrder: number;
  readonly isPrimary: boolean;
}

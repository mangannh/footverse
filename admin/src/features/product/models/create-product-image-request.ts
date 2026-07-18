/** Create a product image (dto-spec §9). Mirrors the frozen DTO field-for-field. */
export interface CreateProductImageRequest {
  readonly imageUrl: string;
  readonly displayOrder: number;
  readonly isPrimary: boolean;
}

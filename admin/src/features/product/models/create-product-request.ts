/** Create a product (dto-spec §9). Mirrors the frozen DTO field-for-field. */
export interface CreateProductRequest {
  readonly name: string;
  readonly description?: string;
  readonly basePrice: number;
  readonly categoryId: number;
  readonly brandId: number;
}

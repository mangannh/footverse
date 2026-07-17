/** Create a brand (dto-spec §11). Mirrors the frozen DTO field-for-field. */
export interface CreateBrandRequest {
  readonly name: string;
  readonly logoUrl?: string;
  readonly description?: string;
}

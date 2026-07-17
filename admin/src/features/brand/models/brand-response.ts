/** A brand's profile (dto-spec §11). Mirrors the frozen DTO field-for-field. */
export interface BrandResponse {
  readonly id: number;
  readonly name: string;
  readonly logoUrl?: string;
  readonly description?: string;
}

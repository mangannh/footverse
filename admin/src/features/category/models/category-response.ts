/** A category's profile (dto-spec §10). Mirrors the frozen DTO field-for-field. */
export interface CategoryResponse {
  readonly id: number;
  readonly name: string;
  readonly description?: string;
}

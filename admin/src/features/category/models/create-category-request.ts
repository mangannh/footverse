/** Create a category (dto-spec §10). Mirrors the frozen DTO field-for-field. */
export interface CreateCategoryRequest {
  readonly name: string;
  readonly description?: string;
}

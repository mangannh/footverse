/**
 * Pagination wrapper for list endpoints (dto-spec §5). Mirrors the frozen DTO
 * field-for-field.
 */
export interface PageResponse<T> {
  /** Page of items. */
  readonly content: readonly T[];
  /** Zero-based page index. */
  readonly page: number;
  /** Page size. */
  readonly size: number;
  /** Total matching elements. */
  readonly totalElements: number;
  /** Total pages. */
  readonly totalPages: number;
  /** Whether this is the last page. */
  readonly last: boolean;
}

/**
 * One row of the ADMIN dashboard's trailing twelve-month revenue series
 * (dto-spec §15, Sprint 13). The dashboard always returns exactly twelve rows
 * — the current month and the eleven before it, oldest first — zero-filled
 * server-side for a month with no `DELIVERED` orders. Mirrors the frozen DTO
 * field-for-field.
 */
export interface MonthlyRevenueResponse {
  readonly year: number;
  readonly month: number;
  readonly revenue: number;
  readonly orderCount: number;
}

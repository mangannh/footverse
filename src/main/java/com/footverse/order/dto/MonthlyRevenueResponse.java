package com.footverse.order.dto;

import java.math.BigDecimal;

/**
 * One row of the ADMIN dashboard's trailing twelve-month revenue series (dto-spec §15, Sprint 13).
 * The dashboard always returns exactly twelve rows — the current month and the eleven before it,
 * oldest first — zero-filled by the service for a month with no {@code DELIVERED} orders; the
 * repository aggregate returns rows only for months that occur.
 *
 * @param year       the calendar year
 * @param month      the calendar month, 1–12
 * @param revenue    the sum of {@code total} over {@code DELIVERED} orders placed in this month
 * @param orderCount the number of {@code DELIVERED} orders placed in this month
 */
public record MonthlyRevenueResponse(int year, int month, BigDecimal revenue, int orderCount) {
}

package com.footverse.order.dto;

import com.footverse.order.entity.OrderStatus;

/**
 * One row of the ADMIN dashboard's per-status order count (dto-spec §15, Sprint 13). The dashboard
 * always returns exactly one row per {@link OrderStatus} value, zero-filled by the service for a
 * status with no orders — the repository aggregate returns rows only for statuses that occur.
 *
 * @param status the status this row counts
 * @param count  the number of orders currently at this status
 */
public record OrderStatusCountResponse(OrderStatus status, long count) {
}

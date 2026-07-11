package com.footverse.order.mapper;

import java.util.List;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import com.footverse.order.dto.OrderDetailResponse;
import com.footverse.order.dto.OrderItemResponse;
import com.footverse.order.dto.OrderSummaryResponse;
import com.footverse.order.entity.Order;
import com.footverse.order.entity.OrderItem;

/**
 * Maps {@code order}-module entities to their response DTOs. Every mapping is pure field copying —
 * no aggregation and no cross-service or repository calls (architecture-spec §9).
 *
 * <p>The two aggregate targets, {@code itemCount} on the summary and {@code items} on the detail,
 * are <strong>not</strong> computed here: they are supplied by {@code OrderService}, which owns the
 * aggregation, and passed in as method parameters (the responses are immutable records, so they
 * cannot be completed after construction). The mapper only copies the order's own fields — including
 * {@code couponCode} from the same-aggregate {@code coupon.code}, which is a plain reference walk,
 * not an aggregation.</p>
 */
@Mapper
public interface OrderMapper {

    /**
     * Maps an order item to its response representation. Pure single-entity mapping; every field
     * maps by name.
     *
     * @param item the order item entity
     * @return the response DTO
     */
    OrderItemResponse toResponse(OrderItem item);

    /**
     * Maps an order to its summary response, copying only the order's own fields. The aggregate
     * {@code itemCount} is supplied by the service, which computes the sum of the order-item
     * quantities; the mapper never computes it.
     *
     * @param order     the order entity
     * @param itemCount the sum of the order-item quantities, computed by the service
     * @return the summary response
     */
    OrderSummaryResponse toSummaryResponse(Order order, int itemCount);

    /**
     * Maps an order to its detail response, copying the order's own fields and the applied coupon's
     * code ({@code coupon.code}, {@code null} when no coupon was applied). The {@code items} list is
     * supplied by the service, which assembles it from the order's lines; the mapper never builds it.
     *
     * @param order the order entity
     * @param items the order's line responses, assembled by the service
     * @return the detail response
     */
    @Mapping(target = "couponCode", source = "order.coupon.code")
    OrderDetailResponse toDetailResponse(Order order, List<OrderItemResponse> items);
}

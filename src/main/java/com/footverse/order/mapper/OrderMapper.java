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
     * Maps an order item to its response representation. Pure single-entity mapping; every own field
     * maps by name from {@code item}. The {@code productId} is <strong>not</strong> a field of the
     * order line (it stores only {@code productVariantId}, database-spec §12) — it is resolved by
     * {@code OrderService} through the {@code ProductVariantService} dependency the order module
     * already has (architecture-spec §7) and passed in, exactly as {@code itemCount} and {@code items}
     * are supplied to the aggregate mappings; the mapper performs no service or repository call.
     *
     * @param item      the order item entity
     * @param productId the owning product id, resolved by the service
     * @return the response DTO
     */
    @Mapping(target = "productId", source = "productId")
    OrderItemResponse toResponse(OrderItem item, Long productId);

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

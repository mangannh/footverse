package com.footverse.order.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.footverse.order.dto.OrderItemResponse;
import com.footverse.order.entity.OrderItem;

/**
 * Unit test for the generated {@link OrderMapper#toResponse(OrderItem, Long)}. It proves the mapper
 * copies the order line's own snapshot fields and sets the item-01 additive {@code productId} from the
 * id the service resolves and passes in — the order line itself stores only {@code productVariantId}
 * (database-spec §12) — with no service or repository call (architecture-spec §9).
 */
class OrderMapperTest {

    private final OrderMapper mapper = new OrderMapperImpl();

    /**
     * An order line maps to its response with the snapshot fields copied by name and the resolved
     * {@code productId} taken from the passed-in argument.
     */
    @Test
    void toResponseCopiesSnapshotFieldsAndSetsResolvedProductId() {
        OrderItem item = new OrderItem();
        item.setId(1L);
        item.setProductVariantId(7L);
        item.setProductName("Air Force 1");
        item.setProductImageUrl("img.png");
        item.setColor("Black");
        item.setSize("42");
        item.setUnitPrice(new BigDecimal("100.00"));
        item.setQuantity(2);
        item.setLineTotal(new BigDecimal("200.00"));

        OrderItemResponse response = mapper.toResponse(item, 100L);

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.productVariantId()).isEqualTo(7L);
        assertThat(response.productId()).isEqualTo(100L);
        assertThat(response.productName()).isEqualTo("Air Force 1");
        assertThat(response.productImageUrl()).isEqualTo("img.png");
        assertThat(response.color()).isEqualTo("Black");
        assertThat(response.size()).isEqualTo("42");
        assertThat(response.unitPrice()).isEqualByComparingTo("100.00");
        assertThat(response.quantity()).isEqualTo(2);
        assertThat(response.lineTotal()).isEqualByComparingTo("200.00");
    }
}

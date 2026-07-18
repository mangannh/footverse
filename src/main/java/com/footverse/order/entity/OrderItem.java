package com.footverse.order.entity;

import java.math.BigDecimal;

import com.footverse.common.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import lombok.Getter;
import lombok.Setter;

/**
 * One line of an {@link Order}: a purchased quantity of a single product variant. Maps to the
 * {@code order_item} table (database-spec §10.12); audit timestamps are inherited from
 * {@link BaseEntity}.
 *
 * <p>Owns its order through a unidirectional lazy {@code @ManyToOne} on the
 * {@code fk_order_item_orders} foreign key (CASCADE on order delete). The variant is referenced by
 * {@link #productVariantId} as a plain {@code Long}, never as a JPA association — mirroring the
 * {@code CartItem} precedent — so the {@code order} module does not import the {@code product}
 * module's entities; the database still enforces referential integrity through the
 * {@code fk_order_item_product_variant} RESTRICT foreign key. The product name, image, color, size,
 * and unit price are snapshots frozen at checkout (database-spec §12).</p>
 *
 * <p>{@link #unitCostPrice} is a further checkout snapshot (database-spec §10.12/§12, Sprint 12):
 * the variant's unit cost basis <em>as of the sale</em>, written once at checkout and never
 * restated by a later cost edit — the immutable margin basis a future dashboard (Sprint 13) will
 * read. It is {@code null} for every line placed before this snapshot existed; {@code null} means
 * exactly that ("placed before cost tracking"), <strong>never</strong> that the item was free. It
 * is exposed by no DTO and participates in no computation in Sprint 12.</p>
 */
@Getter
@Setter
@Entity
@Table(name = "order_item")
public class OrderItem extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "product_variant_id", nullable = false)
    private Long productVariantId;

    @Column(name = "product_name", nullable = false, length = 255)
    private String productName;

    @Column(name = "product_image_url", length = 512)
    private String productImageUrl;

    @Column(nullable = false, length = 50)
    private String color;

    @Column(nullable = false, length = 20)
    private String size;

    @Column(name = "unit_price", nullable = false, precision = 12, scale = 2)
    private BigDecimal unitPrice;

    @Column(nullable = false)
    private int quantity;

    @Column(name = "line_total", nullable = false, precision = 12, scale = 2)
    private BigDecimal lineTotal;

    @Column(name = "unit_cost_price", precision = 12, scale = 2)
    private BigDecimal unitCostPrice;
}

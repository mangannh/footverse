package com.footverse.product.entity;

import java.math.BigDecimal;

import com.footverse.common.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import lombok.Getter;
import lombok.Setter;

/**
 * A color-and-size-specific stock-keeping unit of a {@link Product}. Maps to the
 * {@code product_variant} table (database-spec §10.8); audit timestamps are inherited from
 * {@link BaseEntity}.
 *
 * <p>Owns its product via a unidirectional lazy {@code @ManyToOne}. The {@code sku} is unique and
 * each {@code (product, color, size)} triple is unique — one product carries all of its colorways,
 * so the same size may repeat across colors and the same color across sizes. The effective selling
 * price is {@link #priceOverride} when set, otherwise the owning product's {@code basePrice}.</p>
 *
 * <p>{@link #costPrice} is the ADMIN-only unit cost basis (business-rules → Product Variant): it is
 * exposed only through the ADMIN product read surface and never on the public catalog.</p>
 */
@Getter
@Setter
@Entity
@Table(name = "product_variant", uniqueConstraints = {
        @UniqueConstraint(name = "uk_product_variant_product_id_color_size",
                columnNames = {"product_id", "color", "size"})
})
public class ProductVariant extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(nullable = false, length = 50)
    private String color;

    @Column(nullable = false, length = 20)
    private String size;

    @Column(name = "stock_quantity", nullable = false)
    private int stockQuantity;

    @Column(nullable = false, unique = true, length = 64)
    private String sku;

    @Column(name = "price_override", precision = 12, scale = 2)
    private BigDecimal priceOverride;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ProductVariantStatus status;

    @Column(name = "cost_price", nullable = false, precision = 12, scale = 2)
    private BigDecimal costPrice;
}

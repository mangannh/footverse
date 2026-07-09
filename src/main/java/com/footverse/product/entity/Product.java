package com.footverse.product.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.footverse.brand.entity.Brand;
import com.footverse.category.entity.Category;
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
 * A sellable product. Maps to the {@code product} table (database-spec §10.6); audit timestamps
 * are inherited from {@link BaseEntity}.
 *
 * <p>A product references exactly one {@link Category} and one {@link Brand} through
 * unidirectional lazy {@code @ManyToOne} associations (the cross-feature direction is
 * Product → Category / Brand). The product has no status column: it is hidden by setting
 * {@link #deletedAt} (soft delete), and purchasability is derived only from its variants.</p>
 */
@Getter
@Setter
@Entity
@Table(name = "product")
public class Product extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 255)
    private String name;

    @Column(length = 2000)
    private String description;

    @Column(name = "base_price", nullable = false, precision = 12, scale = 2)
    private BigDecimal basePrice;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id", nullable = false)
    private Category category;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "brand_id", nullable = false)
    private Brand brand;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
}

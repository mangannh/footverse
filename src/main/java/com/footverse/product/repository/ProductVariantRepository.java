package com.footverse.product.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.product.entity.ProductVariant;

/**
 * Data access for {@link ProductVariant}. Standard CRUD is inherited from {@link JpaRepository};
 * the variant-specific reads and uniqueness checks below serve {@code ProductVariantService}.
 */
public interface ProductVariantRepository extends JpaRepository<ProductVariant, Long> {

    /**
     * Returns every variant of a product.
     *
     * @param productId the owning product id
     * @return the variants (empty when the product has none)
     */
    List<ProductVariant> findByProductId(Long productId);

    /**
     * Returns every variant of the given products in a single query, for batch availability
     * computation (avoids the per-product N+1 in catalog search).
     *
     * @param productIds the owning product ids
     * @return the variants of those products (empty when none have any)
     */
    List<ProductVariant> findByProductIdIn(Collection<Long> productIds);

    /**
     * Checks whether the product already has a variant of the given size ({@code (product, size)}
     * uniqueness).
     *
     * @param productId the owning product id
     * @param size      the size to check
     * @return {@code true} if such a variant exists
     */
    boolean existsByProductIdAndSize(Long productId, String size);

    /**
     * Checks whether any variant already uses the given SKU (global {@code sku} uniqueness).
     *
     * @param sku the SKU to check
     * @return {@code true} if a variant with the SKU exists
     */
    boolean existsBySku(String sku);
}

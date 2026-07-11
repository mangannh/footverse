package com.footverse.product.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.footverse.product.entity.ProductVariant;

import jakarta.persistence.LockModeType;

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

    /**
     * Finds a variant by id acquiring a {@code PESSIMISTIC_WRITE} row lock, mirroring the Sprint 2
     * locking precedent {@code findByIdAndDeletedAtIsNullForUpdate}. The variant row is the
     * serialization point for stock writes: a concurrent checkout or cancellation touching the same
     * variant blocks here until the holder commits, so the counter is mutated by one transaction at
     * a time (architecture-spec §19). The variant carries no soft-delete state (it has no
     * {@code deleted_at}; database-spec §10.8), so no such filter applies.
     *
     * @param id the variant id
     * @return the variant if it exists, otherwise empty
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT v FROM ProductVariant v WHERE v.id = :id")
    Optional<ProductVariant> findByIdForUpdate(@Param("id") Long id);
}

package com.footverse.product.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.footverse.product.entity.ProductImage;

import jakarta.persistence.LockModeType;

/**
 * Data access for {@link ProductImage}. Standard CRUD is inherited from {@link JpaRepository};
 * the reads below serve {@code ProductService} when it assembles product responses.
 */
public interface ProductImageRepository extends JpaRepository<ProductImage, Long> {

    /**
     * Returns a product's images ordered by {@code displayOrder} ascending (business-rules →
     * Product Image), for the product-detail response.
     *
     * @param productId the owning product id
     * @return the images in display order (empty when the product has none)
     */
    List<ProductImage> findByProductIdOrderByDisplayOrderAsc(Long productId);

    /**
     * Returns the primary image of each given product in a single query, for the
     * {@code primaryImageUrl} of the product summaries (avoids the per-product N+1 in catalog
     * search). Explicit {@code @Query} to avoid the {@code isPrimary} boolean derived-query naming
     * ambiguity.
     *
     * @param productIds the owning product ids
     * @return the primary images of those products (at most one per product)
     */
    @Query("SELECT i FROM ProductImage i WHERE i.product.id IN :productIds AND i.isPrimary = true")
    List<ProductImage> findPrimaryByProductIdIn(@Param("productIds") Collection<Long> productIds);

    /**
     * Returns a product's current primary image(s) with a {@code PESSIMISTIC_WRITE} (current) read,
     * used by the write path to clear the previous primary. The locking read observes the latest
     * committed rows regardless of the transaction's {@code REPEATABLE READ} snapshot, so a
     * concurrent primary change cannot be missed (never used by the public read path).
     *
     * @param productId the owning product id
     * @return the product's primary image(s), locked for update
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM ProductImage i WHERE i.product.id = :productId AND i.isPrimary = true")
    List<ProductImage> findPrimaryByProductIdForUpdate(@Param("productId") Long productId);
}

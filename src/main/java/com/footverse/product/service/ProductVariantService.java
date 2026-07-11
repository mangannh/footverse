package com.footverse.product.service;

import java.util.Collection;
import java.util.List;
import java.util.Map;

import com.footverse.product.dto.CreateProductVariantRequest;
import com.footverse.product.dto.ProductVariantPurchaseSnapshot;
import com.footverse.product.dto.ProductVariantResponse;
import com.footverse.product.dto.UpdateProductVariantRequest;

/**
 * Product-module service that owns everything about a product's variants: reads (with the
 * effective price resolved by {@code ProductVariantMapper}), the purchasability rule, the purchase
 * snapshot the cart and checkout consume, and admin create/update. This is the
 * {@code ProductVariantService} half of the architecture-spec §7 split; it depends on nothing
 * outside the {@code product} module, keeping the service graph acyclic.
 */
public interface ProductVariantService {

    /**
     * Returns the variants of a product as responses; the effective price of each is resolved by
     * the mapper, never recomputed here.
     *
     * @param productId the owning product id
     * @return the variant responses (empty when the product has none or does not exist)
     */
    List<ProductVariantResponse> getVariantsByProduct(Long productId);

    /**
     * Reports whether a product has at least one purchasable variant — a variant that is
     * {@code ACTIVE} and has {@code stockQuantity > 0} (business-rules → Product / Product Variant).
     *
     * @param productId the product id
     * @return {@code true} if any variant is purchasable
     */
    boolean hasPurchasableVariant(Long productId);

    /**
     * Reports, for each given product, whether it has at least one purchasable variant — applying
     * the same rule as {@link #hasPurchasableVariant(Long)} but resolving every product in a single
     * variant query (used by catalog search to avoid a per-product N+1). Products with no variant
     * are absent from the result (i.e. not purchasable).
     *
     * @param productIds the product ids to resolve
     * @return a map from product id to whether that product has a purchasable variant; keys are
     *         limited to products that have at least one variant
     */
    Map<Long, Boolean> getPurchasableStateByProductIds(Collection<Long> productIds);

    /**
     * Returns the purchase snapshot of a single variant: the owning product's id / name / primary
     * image URL, the variant's color, size and stock, whether it is {@code ACTIVE}, and the already
     * resolved effective unit price. Callers use the snapshot as-is and never recompute the price
     * (architecture-spec §7).
     *
     * @param variantId the variant id
     * @return the variant's purchase snapshot
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404}
     *         {@code PRODUCT_VARIANT_NOT_FOUND} when no variant has the given id
     */
    ProductVariantPurchaseSnapshot getPurchaseSnapshot(Long variantId);

    /**
     * Creates a variant for a product. The product must exist (and not be soft-deleted); the
     * {@code (product, color, size)} triple and the {@code sku} must be unique.
     *
     * @param productId the owning product id
     * @param request   the validated create payload
     * @return the created variant
     */
    ProductVariantResponse createVariant(Long productId, CreateProductVariantRequest request);

    /**
     * Updates a variant of a product. The variant must belong to the product; a changed
     * {@code (color, size)} pair or {@code sku} must remain unique.
     *
     * @param productId the owning product id
     * @param variantId the id of the variant to update
     * @param request   the validated update payload
     * @return the updated variant
     */
    ProductVariantResponse updateVariant(Long productId, Long variantId, UpdateProductVariantRequest request);

    /**
     * Decrements stock for the given variants, each read under a {@code PESSIMISTIC_WRITE} lock and
     * re-validated (exists, {@code ACTIVE}, sufficient stock) before its counter is reduced
     * (architecture-spec §19; business-rules → Inventory). The whole operation is all-or-nothing:
     * the first variant that fails aborts it with an existing purchase-rule error and leaves no
     * partial write, because the method runs inside the caller's transaction (checkout owns the
     * {@code @Transactional} boundary, architecture-spec §13) and joins it via the default
     * propagation — it never opens a boundary of its own around checkout. Variants are locked in
     * ascending id order so concurrent stock writers cannot deadlock.
     *
     * @param quantitiesByVariantId the quantity to subtract per variant id (each quantity positive)
     * @throws com.footverse.common.exception.BusinessException {@code 400}
     *         {@code PRODUCT_VARIANT_INACTIVE} when a variant is not {@code ACTIVE}, or {@code 400}
     *         {@code PRODUCT_VARIANT_INSUFFICIENT_STOCK} when a variant has too little stock
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404}
     *         {@code PRODUCT_VARIANT_NOT_FOUND} when no variant has a given id
     */
    void decrementStock(Map<Long, Integer> quantitiesByVariantId);

    /**
     * Restores stock for the given variants, each read under a {@code PESSIMISTIC_WRITE} lock and
     * credited back exactly the given quantity (business-rules → Inventory / Cancellation). No
     * checkout rule applies — the status and stock level are not re-validated; the counter is only
     * increased. Like {@link #decrementStock(Map)} it runs inside the caller's (cancellation)
     * transaction and locks variants in ascending id order.
     *
     * @param quantitiesByVariantId the quantity to add back per variant id (each quantity positive)
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404}
     *         {@code PRODUCT_VARIANT_NOT_FOUND} when no variant has a given id
     */
    void restoreStock(Map<Long, Integer> quantitiesByVariantId);
}

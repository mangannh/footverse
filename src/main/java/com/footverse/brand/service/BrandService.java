package com.footverse.brand.service;

import java.util.List;

import com.footverse.brand.dto.BrandResponse;
import com.footverse.brand.dto.CreateBrandRequest;
import com.footverse.brand.dto.UpdateBrandRequest;

/**
 * Brand-module façade for brand business logic and the cross-feature existence check the product
 * module needs. This is the only entry point into brand data for other features
 * (architecture-spec §6/§7); the module is deliberately independent of the {@code product}
 * module — the delete guard relies on the database foreign key, not the product service.
 */
public interface BrandService {

    /**
     * Returns every brand.
     *
     * @return the list of brand responses (empty when none exist)
     */
    List<BrandResponse> getAllBrands();

    /**
     * Creates a new brand. The name must be unique across all brands.
     *
     * @param request the validated create payload
     * @return the created brand
     */
    BrandResponse createBrand(CreateBrandRequest request);

    /**
     * Updates an existing brand. The new name must not collide with a different brand.
     *
     * @param id      the id of the brand to update
     * @param request the validated update payload
     * @return the updated brand
     */
    BrandResponse updateBrand(Long id, UpdateBrandRequest request);

    /**
     * Deletes a brand. The delete is guarded by the {@code product.brand_id} foreign key
     * ({@code RESTRICT}); a brand still referenced by a product cannot be removed.
     *
     * @param id the id of the brand to delete
     */
    void deleteBrand(Long id);

    /**
     * Checks whether a brand with the given id exists. Exposed for the product module's
     * create-time brand validation.
     *
     * @param id the brand id to check
     * @return {@code true} if a brand with the id exists
     */
    boolean existsById(Long id);
}

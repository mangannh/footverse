package com.footverse.product.controller;

import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.common.dto.ApiResponse;
import com.footverse.common.dto.PageResponse;
import com.footverse.product.dto.CreateProductImageRequest;
import com.footverse.product.dto.CreateProductRequest;
import com.footverse.product.dto.CreateProductVariantRequest;
import com.footverse.product.dto.ProductDetailResponse;
import com.footverse.product.dto.ProductImageResponse;
import com.footverse.product.dto.ProductSummaryResponse;
import com.footverse.product.dto.ProductVariantResponse;
import com.footverse.product.dto.UpdateProductImageRequest;
import com.footverse.product.dto.UpdateProductRequest;
import com.footverse.product.dto.UpdateProductVariantRequest;
import com.footverse.product.service.ProductService;
import com.footverse.product.service.ProductVariantService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;

/**
 * Product endpoints (dto-spec §20): public catalog search and detail, plus admin product, variant,
 * and image management. The controller only validates the request at the boundary and delegates —
 * catalog/aggregate reads and product/image writes to {@link ProductService}, variant writes
 * straight to {@link ProductVariantService} (architecture-spec §7). It holds no business logic and
 * never catches exceptions; role authorization is enforced by the security filter chain
 * (security-spec §6), so the admin operations carry only the Swagger security requirement here.
 */
@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
@Validated
public class ProductController {

    private final ProductService productService;
    private final ProductVariantService productVariantService;

    /**
     * Searches the catalog by optional name / brand / category filters, paginated and sorted
     * (validation-spec §6). Public endpoint.
     *
     * @param name       optional case-insensitive partial product name
     * @param brandId    optional brand filter
     * @param categoryId optional category filter
     * @param pageable   the pagination and sort request (default page 0, size 20)
     * @return {@code 200 OK} with the page of product summaries
     */
    @Operation(summary = "Search the product catalog")
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<ProductSummaryResponse>>> searchProducts(
            @RequestParam(required = false) @Size(max = 255) String name,
            @RequestParam(required = false) @Positive Long brandId,
            @RequestParam(required = false) @Positive Long categoryId,
            @PageableDefault(size = 20) Pageable pageable) {
        PageResponse<ProductSummaryResponse> page =
                productService.searchProducts(name, brandId, categoryId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(page));
    }

    /**
     * Returns the full detail of a product. Public endpoint.
     *
     * @param id the product id
     * @return {@code 200 OK} with the product detail
     */
    @Operation(summary = "Get product detail")
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ProductDetailResponse>> getProduct(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.ok(productService.getProductDetail(id)));
    }

    /**
     * Creates a product. Admin only.
     *
     * @param request the validated create payload
     * @return {@code 201 Created} with the created product's detail
     */
    @Operation(summary = "Create a product")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping
    public ResponseEntity<ApiResponse<ProductDetailResponse>> createProduct(
            @Valid @RequestBody CreateProductRequest request) {
        ProductDetailResponse response = productService.createProduct(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    /**
     * Updates a product. Admin only.
     *
     * @param id      the id of the product to update
     * @param request the validated update payload
     * @return {@code 200 OK} with the updated product's detail
     */
    @Operation(summary = "Update a product")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<ProductDetailResponse>> updateProduct(
            @PathVariable Long id,
            @Valid @RequestBody UpdateProductRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(productService.updateProduct(id, request)));
    }

    /**
     * Soft-deletes a product. Admin only.
     *
     * @param id the id of the product to delete
     * @return {@code 200 OK} with an empty envelope
     */
    @Operation(summary = "Delete a product")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null));
    }

    /**
     * Creates a variant for a product. Admin only; delegates straight to
     * {@link ProductVariantService}.
     *
     * @param id      the owning product id
     * @param request the validated create payload
     * @return {@code 201 Created} with the created variant
     */
    @Operation(summary = "Create a product variant")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/{id}/variants")
    public ResponseEntity<ApiResponse<ProductVariantResponse>> createVariant(
            @PathVariable Long id,
            @Valid @RequestBody CreateProductVariantRequest request) {
        ProductVariantResponse response = productVariantService.createVariant(id, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    /**
     * Updates a variant of a product. Admin only; delegates straight to
     * {@link ProductVariantService}.
     *
     * @param id        the owning product id
     * @param variantId the id of the variant to update
     * @param request   the validated update payload
     * @return {@code 200 OK} with the updated variant
     */
    @Operation(summary = "Update a product variant")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/{id}/variants/{variantId}")
    public ResponseEntity<ApiResponse<ProductVariantResponse>> updateVariant(
            @PathVariable Long id,
            @PathVariable Long variantId,
            @Valid @RequestBody UpdateProductVariantRequest request) {
        ProductVariantResponse response = productVariantService.updateVariant(id, variantId, request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * Creates an image for a product. Admin only.
     *
     * @param id      the owning product id
     * @param request the validated create payload
     * @return {@code 201 Created} with the created image
     */
    @Operation(summary = "Create a product image")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/{id}/images")
    public ResponseEntity<ApiResponse<ProductImageResponse>> createImage(
            @PathVariable Long id,
            @Valid @RequestBody CreateProductImageRequest request) {
        ProductImageResponse response = productService.createImage(id, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    /**
     * Updates an image of a product. Admin only.
     *
     * @param id      the owning product id
     * @param imageId the id of the image to update
     * @param request the validated update payload
     * @return {@code 200 OK} with the updated image
     */
    @Operation(summary = "Update a product image")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/{id}/images/{imageId}")
    public ResponseEntity<ApiResponse<ProductImageResponse>> updateImage(
            @PathVariable Long id,
            @PathVariable Long imageId,
            @Valid @RequestBody UpdateProductImageRequest request) {
        ProductImageResponse response = productService.updateImage(id, imageId, request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }
}

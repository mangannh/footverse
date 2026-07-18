package com.footverse.product.service;

import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.ResourceNotFoundException;
import com.footverse.product.dto.AdminProductVariantResponse;
import com.footverse.product.dto.CreateProductVariantRequest;
import com.footverse.product.dto.ProductVariantPurchaseSnapshot;
import com.footverse.product.dto.ProductVariantResponse;
import com.footverse.product.dto.UpdateProductVariantRequest;
import com.footverse.product.entity.Product;
import com.footverse.product.entity.ProductImage;
import com.footverse.product.entity.ProductVariant;
import com.footverse.product.entity.ProductVariantStatus;
import com.footverse.product.mapper.ProductVariantMapper;
import com.footverse.product.repository.ProductImageRepository;
import com.footverse.product.repository.ProductRepository;
import com.footverse.product.repository.ProductVariantRepository;

import lombok.RequiredArgsConstructor;

/**
 * Default {@link ProductVariantService} implementation backed by the {@code product}-module
 * repositories and {@link ProductVariantMapper}. It owns the variant business rules —
 * {@code (product, color, size)} and {@code sku} uniqueness and the purchasability rule — and never
 * calls another feature's service, so the bean graph stays acyclic (architecture-spec §6/§7).
 * The effective price is resolved solely by the mapper and is never recomputed here.
 */
@Service
@RequiredArgsConstructor
public class ProductVariantServiceImpl implements ProductVariantService {

    private final ProductVariantRepository productVariantRepository;
    private final ProductRepository productRepository;
    private final ProductImageRepository productImageRepository;
    private final ProductVariantMapper productVariantMapper;

    @Override
    @Transactional(readOnly = true)
    public List<ProductVariantResponse> getVariantsByProduct(Long productId) {
        return productVariantRepository.findByProductId(productId).stream()
                .map(productVariantMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<AdminProductVariantResponse> getAdminVariantsByProduct(Long productId) {
        return productVariantRepository.findByProductId(productId).stream()
                .map(productVariantMapper::toAdminResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public boolean hasPurchasableVariant(Long productId) {
        return productVariantRepository.findByProductId(productId).stream()
                .anyMatch(this::isPurchasable);
    }

    @Override
    @Transactional(readOnly = true)
    public Map<Long, Boolean> getPurchasableStateByProductIds(Collection<Long> productIds) {
        Map<Long, Boolean> purchasableByProduct = new HashMap<>();
        for (ProductVariant variant : productVariantRepository.findByProductIdIn(productIds)) {
            purchasableByProduct.merge(variant.getProduct().getId(), isPurchasable(variant), Boolean::logicalOr);
        }
        return purchasableByProduct;
    }

    @Override
    @Transactional(readOnly = true)
    public ProductVariantPurchaseSnapshot getPurchaseSnapshot(Long variantId) {
        ProductVariant variant = productVariantRepository.findById(variantId)
                .orElseThrow(() -> new ResourceNotFoundException("PRODUCT_VARIANT_NOT_FOUND",
                        "Product variant not found"));
        Product product = variant.getProduct();
        return new ProductVariantPurchaseSnapshot(
                variant.getId(),
                product.getId(),
                product.getName(),
                primaryImageUrl(product.getId()),
                variant.getColor(),
                variant.getSize(),
                productVariantMapper.effectivePrice(variant),
                variant.getStockQuantity(),
                variant.getStatus() == ProductVariantStatus.ACTIVE);
    }

    @Override
    @Transactional
    public ProductVariantResponse createVariant(Long productId, CreateProductVariantRequest request) {
        Product product = productRepository.findByIdAndDeletedAtIsNull(productId)
                .orElseThrow(() -> new ResourceNotFoundException("PRODUCT_NOT_FOUND", "Product not found"));
        if (productVariantRepository.existsByProductIdAndColorAndSize(productId, request.color(), request.size())) {
            throw new DuplicateResourceException("PRODUCT_VARIANT_DUPLICATED",
                    "A variant with this color and size already exists for the product");
        }
        if (productVariantRepository.existsBySku(request.sku())) {
            throw new DuplicateResourceException("PRODUCT_VARIANT_SKU_DUPLICATED", "SKU already exists");
        }
        ProductVariant variant = new ProductVariant();
        variant.setProduct(product);
        variant.setColor(request.color());
        variant.setSize(request.size());
        variant.setStockQuantity(request.stockQuantity());
        variant.setSku(request.sku());
        variant.setPriceOverride(request.priceOverride());
        variant.setStatus(request.status());
        variant.setCostPrice(request.costPrice());
        return productVariantMapper.toResponse(productVariantRepository.save(variant));
    }

    @Override
    @Transactional
    public ProductVariantResponse updateVariant(Long productId, Long variantId,
            UpdateProductVariantRequest request) {
        ProductVariant variant = productVariantRepository.findById(variantId)
                .filter(existing -> existing.getProduct().getId().equals(productId))
                .orElseThrow(() -> new ResourceNotFoundException("PRODUCT_VARIANT_NOT_FOUND",
                        "Product variant not found"));
        boolean colorSizeChanged = !variant.getColor().equals(request.color())
                || !variant.getSize().equals(request.size());
        if (colorSizeChanged
                && productVariantRepository.existsByProductIdAndColorAndSize(productId, request.color(),
                        request.size())) {
            throw new DuplicateResourceException("PRODUCT_VARIANT_DUPLICATED",
                    "A variant with this color and size already exists for the product");
        }
        if (!variant.getSku().equals(request.sku())
                && productVariantRepository.existsBySku(request.sku())) {
            throw new DuplicateResourceException("PRODUCT_VARIANT_SKU_DUPLICATED", "SKU already exists");
        }
        variant.setColor(request.color());
        variant.setSize(request.size());
        variant.setStockQuantity(request.stockQuantity());
        variant.setSku(request.sku());
        variant.setPriceOverride(request.priceOverride());
        variant.setStatus(request.status());
        variant.setCostPrice(request.costPrice());
        return productVariantMapper.toResponse(productVariantRepository.save(variant));
    }

    @Override
    @Transactional
    public void decrementStock(Map<Long, Integer> quantitiesByVariantId) {
        for (Long variantId : new TreeSet<>(quantitiesByVariantId.keySet())) {
            int quantity = quantitiesByVariantId.get(variantId);
            ProductVariant variant = lockVariant(variantId);
            if (variant.getStatus() != ProductVariantStatus.ACTIVE) {
                throw new BusinessException(HttpStatus.BAD_REQUEST, "PRODUCT_VARIANT_INACTIVE",
                        "Product variant is not available for purchase");
            }
            if (variant.getStockQuantity() < quantity) {
                throw new BusinessException(HttpStatus.BAD_REQUEST, "PRODUCT_VARIANT_INSUFFICIENT_STOCK",
                        "Requested quantity exceeds available stock");
            }
            variant.setStockQuantity(variant.getStockQuantity() - quantity);
        }
    }

    @Override
    @Transactional
    public void restoreStock(Map<Long, Integer> quantitiesByVariantId) {
        for (Long variantId : new TreeSet<>(quantitiesByVariantId.keySet())) {
            ProductVariant variant = lockVariant(variantId);
            variant.setStockQuantity(variant.getStockQuantity() + quantitiesByVariantId.get(variantId));
        }
    }

    /**
     * Reads a variant under a {@code PESSIMISTIC_WRITE} row lock, mirroring the Sprint 2
     * primary-image locking precedent ({@code ProductServiceImpl#lockProduct}). The returned variant
     * is managed, so a stock change on it is flushed with the caller's transaction — no explicit
     * {@code save} is needed.
     *
     * @param variantId the variant id to lock
     * @return the locked variant
     * @throws ResourceNotFoundException {@code 404} {@code PRODUCT_VARIANT_NOT_FOUND} when no variant
     *         has the id
     */
    private ProductVariant lockVariant(Long variantId) {
        return productVariantRepository.findByIdForUpdate(variantId)
                .orElseThrow(() -> new ResourceNotFoundException("PRODUCT_VARIANT_NOT_FOUND",
                        "Product variant not found"));
    }

    /**
     * Returns a product's primary image URL, reusing the batch primary-image read rather than
     * adding a second query for the single-product case. A product without a primary image simply
     * has no row, which resolves to {@code null} — never an exception or a placeholder.
     *
     * @param productId the owning product id
     * @return the primary image URL, or {@code null} when the product has none
     */
    private String primaryImageUrl(Long productId) {
        return productImageRepository.findPrimaryByProductIdIn(List.of(productId)).stream()
                .findFirst()
                .map(ProductImage::getImageUrl)
                .orElse(null);
    }

    /**
     * A variant is purchasable when it is {@code ACTIVE} and has stock on hand.
     *
     * @param variant the variant to test
     * @return {@code true} if the variant is purchasable
     */
    private boolean isPurchasable(ProductVariant variant) {
        return variant.getStatus() == ProductVariantStatus.ACTIVE && variant.getStockQuantity() > 0;
    }
}

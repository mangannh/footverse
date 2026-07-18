package com.footverse.product.mapper;

import java.math.BigDecimal;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import com.footverse.product.dto.AdminProductVariantResponse;
import com.footverse.product.dto.ProductVariantResponse;
import com.footverse.product.entity.ProductVariant;

/**
 * Maps {@link ProductVariant} entities to their response DTOs. Pure mapping only; the sole derived
 * value is the effective price computed in {@link #effectivePrice(ProductVariant)}. The public
 * {@link #toResponse(ProductVariant)} omits {@code costPrice}; only the ADMIN
 * {@link #toAdminResponse(ProductVariant)} carries it (Sprint 11).
 */
@Mapper
public interface ProductVariantMapper {

    /**
     * Maps a product variant to its public response representation, resolving the effective price.
     * Never exposes {@code costPrice}.
     *
     * @param variant the product variant entity
     * @return the public response DTO
     */
    @Mapping(target = "price", source = "variant", qualifiedByName = "effectivePrice")
    ProductVariantResponse toResponse(ProductVariant variant);

    /**
     * Maps a product variant to its ADMIN response representation, resolving the effective price and
     * carrying the ADMIN-only {@code costPrice}.
     *
     * @param variant the product variant entity
     * @return the ADMIN response DTO
     */
    @Mapping(target = "price", source = "variant", qualifiedByName = "effectivePrice")
    AdminProductVariantResponse toAdminResponse(ProductVariant variant);

    /**
     * Computes the effective selling price: the variant's {@code priceOverride} when present,
     * otherwise the owning product's {@code basePrice}.
     *
     * @param variant the product variant entity
     * @return the effective price
     */
    @Named("effectivePrice")
    default BigDecimal effectivePrice(ProductVariant variant) {
        BigDecimal priceOverride = variant.getPriceOverride();
        return priceOverride != null ? priceOverride : variant.getProduct().getBasePrice();
    }
}

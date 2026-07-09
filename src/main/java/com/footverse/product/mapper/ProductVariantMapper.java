package com.footverse.product.mapper;

import java.math.BigDecimal;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import com.footverse.product.dto.ProductVariantResponse;
import com.footverse.product.entity.ProductVariant;

/**
 * Maps {@link ProductVariant} entities to their response DTO. Pure mapping only; the sole derived
 * value is the effective price computed in {@link #effectivePrice(ProductVariant)}.
 */
@Mapper
public interface ProductVariantMapper {

    /**
     * Maps a product variant to its response representation, resolving the effective price.
     *
     * @param variant the product variant entity
     * @return the response DTO
     */
    @Mapping(target = "price", source = "variant", qualifiedByName = "effectivePrice")
    ProductVariantResponse toResponse(ProductVariant variant);

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

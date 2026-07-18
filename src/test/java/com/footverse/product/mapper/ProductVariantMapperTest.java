package com.footverse.product.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.footverse.product.dto.AdminProductVariantResponse;
import com.footverse.product.dto.ProductVariantResponse;
import com.footverse.product.entity.Product;
import com.footverse.product.entity.ProductVariant;
import com.footverse.product.entity.ProductVariantStatus;

/**
 * Unit test for the generated {@link ProductVariantMapper}. It proves the pure mapping resolves the
 * effective {@code price} and — for the ADMIN response — carries the ADMIN-only {@code costPrice}
 * and the <strong>raw</strong> {@code priceOverride} (Sprint 11), without any service or repository
 * call (architecture-spec §9). The raw override lets the ADMIN client distinguish "no override"
 * from "explicit override" on edit rather than inferring it from a price comparison; the public
 * {@link ProductVariantResponse} carries neither cost nor the raw override.
 */
class ProductVariantMapperTest {

    private final ProductVariantMapper mapper = new ProductVariantMapperImpl();

    private ProductVariant variant(BigDecimal basePrice, BigDecimal priceOverride) {
        Product product = new Product();
        product.setBasePrice(basePrice);
        ProductVariant variant = new ProductVariant();
        variant.setId(10L);
        variant.setProduct(product);
        variant.setColor("Black");
        variant.setSize("42");
        variant.setSku("SKU-42");
        variant.setStockQuantity(5);
        variant.setPriceOverride(priceOverride);
        variant.setStatus(ProductVariantStatus.ACTIVE);
        variant.setCostPrice(new BigDecimal("80.00"));
        return variant;
    }

    /**
     * The ADMIN response carries the raw {@code priceOverride} when the variant has one, with the
     * effective {@code price} equal to that override.
     */
    @Test
    void toAdminResponseCarriesRawPriceOverrideWhenSet() {
        AdminProductVariantResponse response =
                mapper.toAdminResponse(variant(new BigDecimal("150.00"), new BigDecimal("120.00")));

        assertThat(response.price()).isEqualByComparingTo("120.00");
        assertThat(response.priceOverride()).isEqualByComparingTo("120.00");
        assertThat(response.costPrice()).isEqualByComparingTo("80.00");
        assertThat(response.sku()).isEqualTo("SKU-42");
    }

    /**
     * When the variant has no override the ADMIN response's raw {@code priceOverride} is
     * {@code null} while the effective {@code price} falls back to the product's {@code basePrice} —
     * the two are distinct, so the client never infers the override from the effective price.
     */
    @Test
    void toAdminResponseHasNullPriceOverrideWhenFollowingBasePrice() {
        AdminProductVariantResponse response =
                mapper.toAdminResponse(variant(new BigDecimal("150.00"), null));

        assertThat(response.priceOverride()).isNull();
        assertThat(response.price()).isEqualByComparingTo("150.00");
        assertThat(response.costPrice()).isEqualByComparingTo("80.00");
    }

    /**
     * The public response resolves the effective {@code price} but exposes neither the ADMIN-only
     * cost nor the raw override (it has no such fields).
     */
    @Test
    void toResponseResolvesEffectivePriceForPublic() {
        ProductVariantResponse response =
                mapper.toResponse(variant(new BigDecimal("150.00"), new BigDecimal("120.00")));

        assertThat(response.price()).isEqualByComparingTo("120.00");
        assertThat(response.sku()).isEqualTo("SKU-42");
    }
}

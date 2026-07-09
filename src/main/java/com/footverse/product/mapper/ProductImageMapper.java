package com.footverse.product.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import com.footverse.product.dto.ProductImageResponse;
import com.footverse.product.entity.ProductImage;

/**
 * Maps {@link ProductImage} entities to their response DTO. Pure mapping only — no business logic.
 */
@Mapper
public interface ProductImageMapper {

    /**
     * Maps a product image to its response representation. The {@code isPrimary} target is mapped
     * explicitly from the {@code primary} read property, because the boolean {@code is}-prefixed
     * getter and the record component name do not match by MapStruct's default naming.
     *
     * @param image the product image entity
     * @return the response DTO
     */
    @Mapping(target = "isPrimary", source = "primary")
    ProductImageResponse toResponse(ProductImage image);
}

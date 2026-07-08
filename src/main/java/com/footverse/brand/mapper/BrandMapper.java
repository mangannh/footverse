package com.footverse.brand.mapper;

import org.mapstruct.Mapper;

import com.footverse.brand.dto.BrandResponse;
import com.footverse.brand.entity.Brand;

/**
 * Maps {@link Brand} entities to their response DTO. Pure mapping only — no business logic.
 */
@Mapper
public interface BrandMapper {

    /**
     * Maps a brand to its response representation.
     *
     * @param brand the brand entity
     * @return the response DTO
     */
    BrandResponse toResponse(Brand brand);
}

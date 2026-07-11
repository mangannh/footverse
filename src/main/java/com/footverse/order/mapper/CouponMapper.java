package com.footverse.order.mapper;

import org.mapstruct.Mapper;

import com.footverse.order.dto.CouponResponse;
import com.footverse.order.entity.Coupon;

/**
 * Maps {@link Coupon} entities to their response DTO. Pure mapping only — a single entity to a
 * single DTO, with no business logic (architecture-spec §9); every field maps by name.
 */
@Mapper
public interface CouponMapper {

    /**
     * Maps a coupon to its admin response representation.
     *
     * @param coupon the coupon entity
     * @return the response DTO
     */
    CouponResponse toResponse(Coupon coupon);
}

package com.footverse.user.mapper;

import org.mapstruct.Mapper;

import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.User;

/**
 * Maps {@link User} entities to their response DTO. Pure mapping only — no business logic.
 */
@Mapper
public interface UserMapper {

    /**
     * Maps a user to its response representation.
     *
     * @param user the user entity
     * @return the response DTO
     */
    UserResponse toResponse(User user);
}

package com.footverse.order.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.order.entity.Coupon;

/**
 * Data access for {@link Coupon}. The {@code findById} and {@code save} operations required by the
 * admin CRUD are inherited from {@link JpaRepository}; only the code lookups needed by validation
 * and the unique-code check are declared here.
 */
public interface CouponRepository extends JpaRepository<Coupon, Long> {

    /**
     * Finds a coupon by its unique code.
     *
     * @param code the coupon code to look up
     * @return the matching coupon, or empty if none exists
     */
    Optional<Coupon> findByCode(String code);

    /**
     * Checks whether a coupon with the given code exists.
     *
     * @param code the code to check
     * @return {@code true} if a coupon has the code
     */
    boolean existsByCode(String code);
}

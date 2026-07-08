package com.footverse.brand.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.brand.entity.Brand;

/**
 * Data access for {@link Brand}. The {@code existsById} and {@code findById} lookups required by
 * the module are inherited from {@link JpaRepository}; only the name-uniqueness check is declared
 * here.
 */
public interface BrandRepository extends JpaRepository<Brand, Long> {

    /**
     * Checks whether a brand with the given name exists.
     *
     * @param name the name to check
     * @return {@code true} if a brand has the name
     */
    boolean existsByName(String name);
}

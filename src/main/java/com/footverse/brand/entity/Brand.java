package com.footverse.brand.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import com.footverse.common.entity.BaseEntity;

import lombok.Getter;
import lombok.Setter;

/**
 * A product brand. Maps to the {@code brand} table (database-spec §10.3); audit
 * timestamps are inherited from {@link BaseEntity}.
 */
@Getter
@Setter
@Entity
@Table(name = "brand")
public class Brand extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 100)
    private String name;

    @Column(name = "logo_url", length = 512)
    private String logoUrl;

    @Column(length = 2000)
    private String description;
}

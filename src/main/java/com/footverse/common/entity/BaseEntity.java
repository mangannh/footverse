package com.footverse.common.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;

import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import lombok.Getter;

/**
 * Base class for every persistent entity, providing JPA-audited creation and modification
 * timestamps.
 *
 * <p>Business entities extend {@code BaseEntity} so that {@code created_at} and
 * {@code updated_at} are populated automatically by Spring Data JPA auditing (enabled in
 * {@link com.footverse.common.config.JpaAuditingConfig}). Subclasses never assign these
 * timestamps manually.</p>
 */
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    /** Set once when the entity is first persisted; never changed afterwards. */
    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /** Refreshed automatically on every update. */
    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
}

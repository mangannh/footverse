package com.footverse.common.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Enables Spring Data JPA auditing so that the {@code @CreatedDate} and
 * {@code @LastModifiedDate} fields declared on
 * {@link com.footverse.common.entity.BaseEntity} are populated automatically.
 */
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}

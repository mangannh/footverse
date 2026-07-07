package com.footverse.common.dto;

import java.util.List;

import org.springframework.data.domain.Page;

/**
 * Pagination wrapper for list and search endpoints.
 *
 * @param <T>           the item type
 * @param content       the items on the current page
 * @param page          zero-based page index
 * @param size          page size
 * @param totalElements total number of matching elements across all pages
 * @param totalPages    total number of pages
 * @param last          whether this is the last page
 */
public record PageResponse<T>(
        List<T> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        boolean last) {

    /**
     * Builds a {@code PageResponse} from a Spring Data {@link Page}, mirroring its metadata.
     *
     * @param source the source page
     * @param <T>    the item type
     * @return a pagination wrapper reflecting the source page
     */
    public static <T> PageResponse<T> from(Page<T> source) {
        return new PageResponse<>(
                source.getContent(),
                source.getNumber(),
                source.getSize(),
                source.getTotalElements(),
                source.getTotalPages(),
                source.isLast());
    }
}

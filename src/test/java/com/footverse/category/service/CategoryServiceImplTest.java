package com.footverse.category.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

import com.footverse.category.dto.CategoryResponse;
import com.footverse.category.dto.CreateCategoryRequest;
import com.footverse.category.dto.UpdateCategoryRequest;
import com.footverse.category.entity.Category;
import com.footverse.category.mapper.CategoryMapper;
import com.footverse.category.repository.CategoryRepository;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.InvalidOperationException;
import com.footverse.common.exception.ResourceNotFoundException;

/**
 * Unit tests for {@link CategoryServiceImpl}: listing, name-uniqueness on create/update, the
 * not-found paths, and the FK-guarded delete translated to {@code 409 CATEGORY_IN_USE}.
 */
@ExtendWith(MockitoExtension.class)
class CategoryServiceImplTest {

    @Mock
    private CategoryRepository categoryRepository;

    @Mock
    private CategoryMapper categoryMapper;

    private CategoryServiceImpl service;

    private void init() {
        service = new CategoryServiceImpl(categoryRepository, categoryMapper);
    }

    private Category category(Long id, String name) {
        Category category = new Category();
        category.setId(id);
        category.setName(name);
        category.setDescription("desc");
        return category;
    }

    /**
     * Listing maps every entity through the mapper.
     */
    @Test
    void getAllCategoriesReturnsMappedList() {
        init();
        Category entity = category(1L, "Sneakers");
        CategoryResponse mapped = new CategoryResponse(1L, "Sneakers", "desc");
        when(categoryRepository.findAll()).thenReturn(List.of(entity));
        when(categoryMapper.toResponse(entity)).thenReturn(mapped);

        assertThat(service.getAllCategories()).containsExactly(mapped);
    }

    /**
     * Creating a category with a free name persists it and returns the mapped response.
     */
    @Test
    void createCategoryPersistsAndReturnsResponse() {
        init();
        CreateCategoryRequest request = new CreateCategoryRequest("Sneakers", "desc");
        CategoryResponse mapped = new CategoryResponse(1L, "Sneakers", "desc");
        when(categoryRepository.existsByName("Sneakers")).thenReturn(false);
        when(categoryRepository.save(any(Category.class))).thenAnswer(inv -> inv.getArgument(0));
        when(categoryMapper.toResponse(any(Category.class))).thenReturn(mapped);

        assertThat(service.createCategory(request)).isEqualTo(mapped);
        ArgumentCaptor<Category> captor = ArgumentCaptor.forClass(Category.class);
        verify(categoryRepository).save(captor.capture());
        assertThat(captor.getValue().getName()).isEqualTo("Sneakers");
        assertThat(captor.getValue().getDescription()).isEqualTo("desc");
    }

    /**
     * A duplicate name is an enveloped {@code 409 CATEGORY_NAME_DUPLICATED}; nothing is saved.
     */
    @Test
    void createCategoryWithDuplicateNameThrowsConflict() {
        init();
        when(categoryRepository.existsByName("Sneakers")).thenReturn(true);

        assertThatThrownBy(() -> service.createCategory(new CreateCategoryRequest("Sneakers", "desc")))
                .isInstanceOf(DuplicateResourceException.class)
                .hasFieldOrPropertyWithValue("errorCode", "CATEGORY_NAME_DUPLICATED")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.CONFLICT);
        verify(categoryRepository, never()).save(any());
    }

    /**
     * Updating applies the new fields when the name is free.
     */
    @Test
    void updateCategoryAppliesChanges() {
        init();
        Category existing = category(1L, "Sneakers");
        CategoryResponse mapped = new CategoryResponse(1L, "Boots", "new");
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(categoryRepository.existsByName("Boots")).thenReturn(false);
        when(categoryRepository.save(existing)).thenReturn(existing);
        when(categoryMapper.toResponse(existing)).thenReturn(mapped);

        assertThat(service.updateCategory(1L, new UpdateCategoryRequest("Boots", "new"))).isEqualTo(mapped);
        assertThat(existing.getName()).isEqualTo("Boots");
        assertThat(existing.getDescription()).isEqualTo("new");
    }

    /**
     * Updating a missing category is a {@code 404}.
     */
    @Test
    void updateMissingCategoryThrowsNotFound() {
        init();
        when(categoryRepository.findById(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.updateCategory(9L, new UpdateCategoryRequest("Boots", "x")))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "CATEGORY_NOT_FOUND");
    }

    /**
     * Changing to a name owned by another category is a {@code 409}.
     */
    @Test
    void updateCategoryToDuplicateNameThrowsConflict() {
        init();
        Category existing = category(1L, "Sneakers");
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(categoryRepository.existsByName("Boots")).thenReturn(true);

        assertThatThrownBy(() -> service.updateCategory(1L, new UpdateCategoryRequest("Boots", "x")))
                .isInstanceOf(DuplicateResourceException.class)
                .hasFieldOrPropertyWithValue("errorCode", "CATEGORY_NAME_DUPLICATED");
        verify(categoryRepository, never()).save(any());
    }

    /**
     * Keeping the same name skips the uniqueness check entirely.
     */
    @Test
    void updateCategoryKeepingSameNameSkipsDuplicateCheck() {
        init();
        Category existing = category(1L, "Sneakers");
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(categoryRepository.save(existing)).thenReturn(existing);
        when(categoryMapper.toResponse(existing)).thenReturn(new CategoryResponse(1L, "Sneakers", "updated"));

        service.updateCategory(1L, new UpdateCategoryRequest("Sneakers", "updated"));

        verify(categoryRepository, never()).existsByName(any());
    }

    /**
     * Deleting an unreferenced category removes it (delete then flush).
     */
    @Test
    void deleteCategoryRemovesEntity() {
        init();
        Category existing = category(1L, "Sneakers");
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(existing));

        service.deleteCategory(1L);

        verify(categoryRepository).delete(existing);
        verify(categoryRepository).flush();
    }

    /**
     * Deleting a missing category is a {@code 404}.
     */
    @Test
    void deleteMissingCategoryThrowsNotFound() {
        init();
        when(categoryRepository.findById(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.deleteCategory(9L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "CATEGORY_NOT_FOUND");
        verify(categoryRepository, never()).delete(any());
    }

    /**
     * A category still referenced by a product cannot be deleted: the FK integrity violation on
     * flush is translated to the enveloped {@code 409 CATEGORY_IN_USE}.
     */
    @Test
    void deleteCategoryStillReferencedThrowsConflict() {
        init();
        Category existing = category(1L, "Sneakers");
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(existing));
        doThrow(new DataIntegrityViolationException("fk")).when(categoryRepository).flush();

        assertThatThrownBy(() -> service.deleteCategory(1L))
                .isInstanceOf(InvalidOperationException.class)
                .hasFieldOrPropertyWithValue("errorCode", "CATEGORY_IN_USE")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.CONFLICT);
    }

    /**
     * {@code existsById} delegates to the repository.
     */
    @Test
    void existsByIdDelegatesToRepository() {
        init();
        when(categoryRepository.existsById(1L)).thenReturn(true);
        when(categoryRepository.existsById(2L)).thenReturn(false);

        assertThat(service.existsById(1L)).isTrue();
        assertThat(service.existsById(2L)).isFalse();
    }
}

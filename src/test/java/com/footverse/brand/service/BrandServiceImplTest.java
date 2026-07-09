package com.footverse.brand.service;

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

import com.footverse.brand.dto.BrandResponse;
import com.footverse.brand.dto.CreateBrandRequest;
import com.footverse.brand.dto.UpdateBrandRequest;
import com.footverse.brand.entity.Brand;
import com.footverse.brand.mapper.BrandMapper;
import com.footverse.brand.repository.BrandRepository;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.InvalidOperationException;
import com.footverse.common.exception.ResourceNotFoundException;

/**
 * Unit tests for {@link BrandServiceImpl}: listing, name-uniqueness on create/update, the
 * not-found paths, and the FK-guarded delete translated to {@code 409 BRAND_IN_USE}.
 */
@ExtendWith(MockitoExtension.class)
class BrandServiceImplTest {

    @Mock
    private BrandRepository brandRepository;

    @Mock
    private BrandMapper brandMapper;

    private BrandServiceImpl service;

    private void init() {
        service = new BrandServiceImpl(brandRepository, brandMapper);
    }

    private Brand brand(Long id, String name) {
        Brand brand = new Brand();
        brand.setId(id);
        brand.setName(name);
        brand.setLogoUrl("logo.png");
        brand.setDescription("desc");
        return brand;
    }

    /**
     * Listing maps every entity through the mapper.
     */
    @Test
    void getAllBrandsReturnsMappedList() {
        init();
        Brand entity = brand(1L, "Nike");
        BrandResponse mapped = new BrandResponse(1L, "Nike", "logo.png", "desc");
        when(brandRepository.findAll()).thenReturn(List.of(entity));
        when(brandMapper.toResponse(entity)).thenReturn(mapped);

        assertThat(service.getAllBrands()).containsExactly(mapped);
    }

    /**
     * Creating a brand with a free name persists it and returns the mapped response.
     */
    @Test
    void createBrandPersistsAndReturnsResponse() {
        init();
        CreateBrandRequest request = new CreateBrandRequest("Nike", "logo.png", "desc");
        BrandResponse mapped = new BrandResponse(1L, "Nike", "logo.png", "desc");
        when(brandRepository.existsByName("Nike")).thenReturn(false);
        when(brandRepository.save(any(Brand.class))).thenAnswer(inv -> inv.getArgument(0));
        when(brandMapper.toResponse(any(Brand.class))).thenReturn(mapped);

        assertThat(service.createBrand(request)).isEqualTo(mapped);
        ArgumentCaptor<Brand> captor = ArgumentCaptor.forClass(Brand.class);
        verify(brandRepository).save(captor.capture());
        assertThat(captor.getValue().getName()).isEqualTo("Nike");
        assertThat(captor.getValue().getLogoUrl()).isEqualTo("logo.png");
    }

    /**
     * A duplicate name is an enveloped {@code 409 BRAND_NAME_DUPLICATED}; nothing is saved.
     */
    @Test
    void createBrandWithDuplicateNameThrowsConflict() {
        init();
        when(brandRepository.existsByName("Nike")).thenReturn(true);

        assertThatThrownBy(() -> service.createBrand(new CreateBrandRequest("Nike", null, null)))
                .isInstanceOf(DuplicateResourceException.class)
                .hasFieldOrPropertyWithValue("errorCode", "BRAND_NAME_DUPLICATED")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.CONFLICT);
        verify(brandRepository, never()).save(any());
    }

    /**
     * Updating applies the new fields when the name is free.
     */
    @Test
    void updateBrandAppliesChanges() {
        init();
        Brand existing = brand(1L, "Nike");
        BrandResponse mapped = new BrandResponse(1L, "Adidas", "a.png", "new");
        when(brandRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(brandRepository.existsByName("Adidas")).thenReturn(false);
        when(brandRepository.save(existing)).thenReturn(existing);
        when(brandMapper.toResponse(existing)).thenReturn(mapped);

        assertThat(service.updateBrand(1L, new UpdateBrandRequest("Adidas", "a.png", "new"))).isEqualTo(mapped);
        assertThat(existing.getName()).isEqualTo("Adidas");
        assertThat(existing.getLogoUrl()).isEqualTo("a.png");
    }

    /**
     * Updating a missing brand is a {@code 404}.
     */
    @Test
    void updateMissingBrandThrowsNotFound() {
        init();
        when(brandRepository.findById(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.updateBrand(9L, new UpdateBrandRequest("Adidas", null, null)))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "BRAND_NOT_FOUND");
    }

    /**
     * Changing to a name owned by another brand is a {@code 409}.
     */
    @Test
    void updateBrandToDuplicateNameThrowsConflict() {
        init();
        Brand existing = brand(1L, "Nike");
        when(brandRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(brandRepository.existsByName("Adidas")).thenReturn(true);

        assertThatThrownBy(() -> service.updateBrand(1L, new UpdateBrandRequest("Adidas", null, null)))
                .isInstanceOf(DuplicateResourceException.class)
                .hasFieldOrPropertyWithValue("errorCode", "BRAND_NAME_DUPLICATED");
        verify(brandRepository, never()).save(any());
    }

    /**
     * Keeping the same name skips the uniqueness check entirely.
     */
    @Test
    void updateBrandKeepingSameNameSkipsDuplicateCheck() {
        init();
        Brand existing = brand(1L, "Nike");
        when(brandRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(brandRepository.save(existing)).thenReturn(existing);
        when(brandMapper.toResponse(existing)).thenReturn(new BrandResponse(1L, "Nike", "logo.png", "updated"));

        service.updateBrand(1L, new UpdateBrandRequest("Nike", "logo.png", "updated"));

        verify(brandRepository, never()).existsByName(any());
    }

    /**
     * Deleting an unreferenced brand removes it (delete then flush).
     */
    @Test
    void deleteBrandRemovesEntity() {
        init();
        Brand existing = brand(1L, "Nike");
        when(brandRepository.findById(1L)).thenReturn(Optional.of(existing));

        service.deleteBrand(1L);

        verify(brandRepository).delete(existing);
        verify(brandRepository).flush();
    }

    /**
     * Deleting a missing brand is a {@code 404}.
     */
    @Test
    void deleteMissingBrandThrowsNotFound() {
        init();
        when(brandRepository.findById(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.deleteBrand(9L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "BRAND_NOT_FOUND");
        verify(brandRepository, never()).delete(any());
    }

    /**
     * A brand still referenced by a product cannot be deleted: the FK integrity violation on flush
     * is translated to the enveloped {@code 409 BRAND_IN_USE}.
     */
    @Test
    void deleteBrandStillReferencedThrowsConflict() {
        init();
        Brand existing = brand(1L, "Nike");
        when(brandRepository.findById(1L)).thenReturn(Optional.of(existing));
        doThrow(new DataIntegrityViolationException("fk")).when(brandRepository).flush();

        assertThatThrownBy(() -> service.deleteBrand(1L))
                .isInstanceOf(InvalidOperationException.class)
                .hasFieldOrPropertyWithValue("errorCode", "BRAND_IN_USE")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.CONFLICT);
    }

    /**
     * {@code existsById} delegates to the repository.
     */
    @Test
    void existsByIdDelegatesToRepository() {
        init();
        when(brandRepository.existsById(1L)).thenReturn(true);
        when(brandRepository.existsById(2L)).thenReturn(false);

        assertThat(service.existsById(1L)).isTrue();
        assertThat(service.existsById(2L)).isFalse();
    }
}

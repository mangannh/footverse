package com.footverse.brand.service;

import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.brand.dto.BrandResponse;
import com.footverse.brand.dto.CreateBrandRequest;
import com.footverse.brand.dto.UpdateBrandRequest;
import com.footverse.brand.entity.Brand;
import com.footverse.brand.mapper.BrandMapper;
import com.footverse.brand.repository.BrandRepository;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.InvalidOperationException;
import com.footverse.common.exception.ResourceNotFoundException;

import lombok.RequiredArgsConstructor;

/**
 * Default {@link BrandService} implementation backed by {@link BrandRepository} and
 * {@link BrandMapper}. It owns the brand business rules — name uniqueness and the delete guard —
 * and stays fully independent of the {@code product} module: the delete relies on the
 * {@code product.brand_id} foreign key ({@code RESTRICT}), never on the product service, so the
 * bean graph remains acyclic (architecture-spec §6/§7).
 */
@Service
@RequiredArgsConstructor
public class BrandServiceImpl implements BrandService {

    private final BrandRepository brandRepository;
    private final BrandMapper brandMapper;

    @Override
    @Transactional(readOnly = true)
    public List<BrandResponse> getAllBrands() {
        return brandRepository.findAll().stream()
                .map(brandMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional
    public BrandResponse createBrand(CreateBrandRequest request) {
        if (brandRepository.existsByName(request.name())) {
            throw new DuplicateResourceException("BRAND_NAME_DUPLICATED", "Brand name already exists");
        }
        Brand brand = new Brand();
        brand.setName(request.name());
        brand.setLogoUrl(request.logoUrl());
        brand.setDescription(request.description());
        return brandMapper.toResponse(brandRepository.save(brand));
    }

    @Override
    @Transactional
    public BrandResponse updateBrand(Long id, UpdateBrandRequest request) {
        Brand brand = brandRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("BRAND_NOT_FOUND", "Brand not found"));
        if (!brand.getName().equals(request.name()) && brandRepository.existsByName(request.name())) {
            throw new DuplicateResourceException("BRAND_NAME_DUPLICATED", "Brand name already exists");
        }
        brand.setName(request.name());
        brand.setLogoUrl(request.logoUrl());
        brand.setDescription(request.description());
        return brandMapper.toResponse(brandRepository.save(brand));
    }

    @Override
    @Transactional
    public void deleteBrand(Long id) {
        Brand brand = brandRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("BRAND_NOT_FOUND", "Brand not found"));
        try {
            brandRepository.delete(brand);
            brandRepository.flush();
        } catch (DataIntegrityViolationException ex) {
            throw new InvalidOperationException("BRAND_IN_USE", "Brand is still referenced by products");
        }
    }

    @Override
    @Transactional(readOnly = true)
    public boolean existsById(Long id) {
        return brandRepository.existsById(id);
    }
}

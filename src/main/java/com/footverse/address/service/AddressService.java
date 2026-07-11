package com.footverse.address.service;

import java.util.List;

import com.footverse.address.dto.AddressResponse;
import com.footverse.address.dto.CreateAddressRequest;
import com.footverse.address.dto.UpdateAddressRequest;

/**
 * Address-module façade for the caller's shipping addresses. Every operation is scoped to the
 * authenticated user resolved through {@code CurrentUserProvider} (security-spec §7) — no method
 * accepts a user id, so a caller can never address another user's rows. The service also enforces
 * the exactly-one-default-per-user invariant (architecture-spec §13).
 */
public interface AddressService {

    /**
     * Returns the caller's own addresses.
     *
     * @return the caller's address responses (empty when they have none)
     */
    List<AddressResponse> getMyAddresses();

    /**
     * Returns one of the caller's addresses by id, ownership-checked. Exposed for checkout, which
     * snapshots the caller's shipping address onto the order; it returns the same
     * {@link AddressResponse} as the other reads, never the {@code Address} entity, so the entity
     * never crosses a module boundary (architecture-spec §7).
     *
     * @param id the id of the address to return
     * @return the caller's address
     * @throws com.footverse.common.exception.BusinessException {@code 403 ADDRESS_FORBIDDEN} when the
     *         address belongs to another user
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 ADDRESS_NOT_FOUND}
     *         when no such address exists
     */
    AddressResponse getMyAddress(Long id);

    /**
     * Creates an address owned by the caller. It becomes the default when it is the caller's first
     * address, or when the request asks for it — in which case the previous default is cleared.
     *
     * @param request the validated create payload
     * @return the created address
     */
    AddressResponse createAddress(CreateAddressRequest request);

    /**
     * Updates one of the caller's addresses. Promoting it to default clears the previous default;
     * an address that is already the default stays the default, so the caller always keeps exactly
     * one.
     *
     * @param id      the id of the address to update
     * @param request the validated update payload
     * @return the updated address
     */
    AddressResponse updateAddress(Long id, UpdateAddressRequest request);

    /**
     * Deletes one of the caller's addresses. The default address can only be deleted when it is the
     * caller's sole address; otherwise another default must be chosen first
     * (business-rules → Shipping Address).
     *
     * @param id the id of the address to delete
     */
    void deleteAddress(Long id);
}

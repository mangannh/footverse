package com.footverse.user.entity;

/**
 * User account role. Stored as its string name (see database-spec §7).
 */
public enum Role {

    /** A regular shopping customer. */
    CUSTOMER,

    /** An administrator managing the catalog, coupons and order status. */
    ADMIN
}

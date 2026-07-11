package com.footverse.order.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.footverse.common.entity.BaseEntity;
import com.footverse.user.entity.User;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import lombok.Getter;
import lombok.Setter;

/**
 * A customer order. Maps to the {@code orders} table (database-spec §10.11) — the JPA entity is
 * {@code Order} while the table is {@code orders}, since {@code order} is a reserved word. Audit
 * timestamps are inherited from {@link BaseEntity}.
 *
 * <p>The owning user is referenced by a unidirectional lazy {@code @ManyToOne} ({@code RESTRICT}, so
 * a user with orders is preserved), and the applied coupon by a nullable lazy {@code @ManyToOne} to
 * the same-module {@link Coupon}. Order items are not mapped as a collection here; they are read
 * through {@code OrderItemRepository} (sprint-4-plan item 07), mirroring how the cart resolves its
 * lines. The shipping and money columns are snapshots frozen at checkout and never recomputed
 * (database-spec §12).</p>
 */
@Getter
@Setter
@Entity
@Table(name = "orders")
public class Order extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "order_code", nullable = false, unique = true, length = 30)
    private String orderCode;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coupon_id")
    private Coupon coupon;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OrderStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method", nullable = false, length = 20)
    private PaymentMethod paymentMethod;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_status", nullable = false, length = 20)
    private PaymentStatus paymentStatus;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal subtotal;

    @Column(name = "discount_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal discountAmount;

    @Column(name = "shipping_fee", nullable = false, precision = 12, scale = 2)
    private BigDecimal shippingFee;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal total;

    @Column(name = "shipping_recipient_name", nullable = false, length = 100)
    private String shippingRecipientName;

    @Column(name = "shipping_recipient_phone", nullable = false, length = 20)
    private String shippingRecipientPhone;

    @Column(name = "shipping_province", nullable = false, length = 100)
    private String shippingProvince;

    @Column(name = "shipping_district", nullable = false, length = 100)
    private String shippingDistrict;

    @Column(name = "shipping_ward", nullable = false, length = 100)
    private String shippingWard;

    @Column(name = "shipping_street_address", nullable = false, length = 255)
    private String shippingStreetAddress;

    @Column(length = 500)
    private String note;

    @Column(name = "cancelled_at")
    private LocalDateTime cancelledAt;

    @Column(name = "delivered_at")
    private LocalDateTime deliveredAt;
}

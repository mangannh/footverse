import { describe, expect, it } from 'vitest';

import type { AdminOrderDetailResponse } from './admin-order-detail-response';
import type { AdminOrderSummaryResponse } from './admin-order-summary-response';
import type { OrderItemResponse } from './order-item-response';
import type { UpdateOrderStatusRequest } from './update-order-status-request';

// Captured backend payloads (dto-spec §15/§17). Response types deserialize a
// captured payload field-for-field. `customerId` / `customerFullName` /
// `customerEmail` / `customerPhone` are ADMIN-only (Sprint 12) — present only
// on the dedicated Admin*Response types, never on the customer-scoped DTOs
// (which this feature never models).
describe('OrderItemResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = {
      id: 1,
      productVariantId: 7,
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: 'https://example.com/air-force-1.png',
      color: 'Black',
      size: '42',
      unitPrice: 100,
      quantity: 2,
      lineTotal: 200,
    };

    const item: OrderItemResponse = JSON.parse(JSON.stringify(payload));

    expect(item).toEqual(payload);
  });

  it('deserializes a payload where productImageUrl is explicitly null', () => {
    const payload = {
      id: 1,
      productVariantId: 7,
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: null,
      color: 'Black',
      size: '42',
      unitPrice: 100,
      quantity: 2,
      lineTotal: 200,
    };

    const item: OrderItemResponse = JSON.parse(JSON.stringify(payload));

    expect(item.productImageUrl).toBeNull();
  });
});

describe('AdminOrderSummaryResponse', () => {
  it('deserializes a captured payload field-for-field, including the customer identity', () => {
    const payload = {
      id: 5,
      orderCode: 'FV-ORDER-5',
      status: 'PENDING',
      paymentStatus: 'UNPAID',
      total: 30200,
      itemCount: 5,
      createdAt: '2026-01-01T00:00:00',
      customerId: 42,
      customerFullName: 'Jane Doe',
      customerEmail: 'jane@example.com',
      customerPhone: '0900000001',
    };

    const summary: AdminOrderSummaryResponse = JSON.parse(JSON.stringify(payload));

    expect(summary).toEqual(payload);
  });
});

describe('AdminOrderDetailResponse', () => {
  it('deserializes a captured payload field-for-field, nesting items and carrying the customer identity', () => {
    const payload = {
      id: 9,
      orderCode: 'FV-ORDER-9',
      status: 'PENDING',
      paymentMethod: 'COD',
      paymentStatus: 'UNPAID',
      subtotal: 200,
      discountAmount: 0,
      shippingFee: 30000,
      total: 30200,
      couponCode: 'SAVE10',
      shippingRecipientName: 'Jane',
      shippingRecipientPhone: '0900000000',
      shippingProvince: 'HCM',
      shippingDistrict: 'D1',
      shippingWard: 'W1',
      shippingStreetAddress: '1 Street',
      note: 'Leave at door',
      items: [
        {
          id: 1,
          productVariantId: 7,
          productId: 100,
          productName: 'Air Force 1',
          productImageUrl: 'https://example.com/air-force-1.png',
          color: 'Black',
          size: '42',
          unitPrice: 100,
          quantity: 2,
          lineTotal: 200,
        },
      ],
      createdAt: '2026-01-01T00:00:00',
      cancelledAt: null,
      deliveredAt: '2026-01-05T00:00:00',
      customerId: 42,
      customerFullName: 'Jane Doe',
      customerEmail: 'jane@example.com',
      customerPhone: '0900000001',
    };

    const detail: AdminOrderDetailResponse = JSON.parse(JSON.stringify(payload));

    expect(detail).toEqual(payload);
    expect(detail.items[0]?.color).toBe('Black');
  });

  it('deserializes a payload where couponCode, note, cancelledAt, and deliveredAt are explicitly null', () => {
    const payload = {
      id: 9,
      orderCode: 'FV-ORDER-9',
      status: 'PENDING',
      paymentMethod: 'COD',
      paymentStatus: 'UNPAID',
      subtotal: 200,
      discountAmount: 0,
      shippingFee: 30000,
      total: 30200,
      couponCode: null,
      shippingRecipientName: 'Jane',
      shippingRecipientPhone: '0900000000',
      shippingProvince: 'HCM',
      shippingDistrict: 'D1',
      shippingWard: 'W1',
      shippingStreetAddress: '1 Street',
      note: null,
      items: [],
      createdAt: '2026-01-01T00:00:00',
      cancelledAt: null,
      deliveredAt: null,
      customerId: 42,
      customerFullName: 'Jane Doe',
      customerEmail: 'jane@example.com',
      customerPhone: '0900000001',
    };

    const detail: AdminOrderDetailResponse = JSON.parse(JSON.stringify(payload));

    expect(detail.couponCode).toBeNull();
    expect(detail.note).toBeNull();
    expect(detail.cancelledAt).toBeNull();
    expect(detail.deliveredAt).toBeNull();
  });
});

describe('UpdateOrderStatusRequest', () => {
  it('serializes the target status', () => {
    const request: UpdateOrderStatusRequest = { status: 'CONFIRMED' };

    expect(JSON.parse(JSON.stringify(request))).toEqual({ status: 'CONFIRMED' });
  });
});

import { describe, expect, it } from 'vitest';

import type { AdminOrderSummaryResponse } from '@/features/order/models/admin-order-summary-response';

import type { BestSellingProductResponse } from './best-selling-product-response';
import type { DashboardResponse } from './dashboard-response';
import type { MonthlyRevenueResponse } from './monthly-revenue-response';
import type { OrderStatusCountResponse } from './order-status-count-response';

// Captured backend payloads (dto-spec §15, Sprint 13). Response types
// deserialize a captured payload field-for-field.

describe('OrderStatusCountResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = { status: 'DELIVERED', count: 9 };

    const row: OrderStatusCountResponse = JSON.parse(JSON.stringify(payload));

    expect(row).toEqual(payload);
  });
});

describe('MonthlyRevenueResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = { year: 2026, month: 7, revenue: 500000, orderCount: 12 };

    const row: MonthlyRevenueResponse = JSON.parse(JSON.stringify(payload));

    expect(row).toEqual(payload);
  });
});

describe('BestSellingProductResponse', () => {
  it('deserializes a captured payload field-for-field', () => {
    const payload = {
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: 'https://example.com/air-force-1.png',
      quantitySold: 10,
      revenue: 1000,
    };

    const row: BestSellingProductResponse = JSON.parse(JSON.stringify(payload));

    expect(row).toEqual(payload);
  });

  it('deserializes a payload where productImageUrl is explicitly null', () => {
    const payload = {
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: null,
      quantitySold: 10,
      revenue: 1000,
    };

    const row: BestSellingProductResponse = JSON.parse(JSON.stringify(payload));

    expect(row.productImageUrl).toBeNull();
  });
});

describe('DashboardResponse', () => {
  const recentOrder: AdminOrderSummaryResponse = {
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

  it('deserializes a full captured payload field-for-field, nesting every row type', () => {
    const payload = {
      totalRevenue: 500000,
      totalOrders: 12,
      grossProfit: 120000,
      profitLinesWithCost: 8,
      profitLinesTotal: 10,
      ordersByStatus: [
        { status: 'PENDING', count: 3 },
        { status: 'CONFIRMED', count: 0 },
        { status: 'SHIPPING', count: 0 },
        { status: 'DELIVERED', count: 9 },
        { status: 'CANCELLED', count: 0 },
      ],
      monthlyRevenue: [{ year: 2026, month: 7, revenue: 500000, orderCount: 12 }],
      bestSellingProducts: [
        {
          productId: 100,
          productName: 'Air Force 1',
          productImageUrl: 'https://example.com/air-force-1.png',
          quantitySold: 10,
          revenue: 1000,
        },
      ],
      recentOrders: [recentOrder],
    };

    const dashboard: DashboardResponse = JSON.parse(JSON.stringify(payload));

    expect(dashboard).toEqual(payload);
    expect(dashboard.ordersByStatus).toHaveLength(5);
    expect(dashboard.recentOrders[0]?.customerFullName).toBe('Jane Doe');
  });

  it('deserializes an empty-store payload — zeros and empty lists, never omitted', () => {
    const payload = {
      totalRevenue: 0,
      totalOrders: 0,
      grossProfit: 0,
      profitLinesWithCost: 0,
      profitLinesTotal: 0,
      ordersByStatus: [
        { status: 'PENDING', count: 0 },
        { status: 'CONFIRMED', count: 0 },
        { status: 'SHIPPING', count: 0 },
        { status: 'DELIVERED', count: 0 },
        { status: 'CANCELLED', count: 0 },
      ],
      monthlyRevenue: Array.from({ length: 12 }, (_, i) => ({
        year: 2026,
        month: i + 1,
        revenue: 0,
        orderCount: 0,
      })),
      bestSellingProducts: [],
      recentOrders: [],
    };

    const dashboard: DashboardResponse = JSON.parse(JSON.stringify(payload));

    expect(dashboard.totalRevenue).toBe(0);
    expect(dashboard.ordersByStatus).toHaveLength(5);
    expect(dashboard.monthlyRevenue).toHaveLength(12);
    expect(dashboard.bestSellingProducts).toEqual([]);
    expect(dashboard.recentOrders).toEqual([]);
  });
});

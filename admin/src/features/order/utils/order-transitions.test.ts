import { describe, expect, it } from 'vitest';

import { getAllowedTransitions, requiresConfirmation } from './order-transitions';
import type { OrderStatus } from '../models/order-status';

const ALL_STATUSES: readonly OrderStatus[] = [
  'PENDING',
  'CONFIRMED',
  'SHIPPING',
  'DELIVERED',
  'CANCELLED',
];

describe('getAllowedTransitions', () => {
  it('PENDING allows CONFIRMED and CANCELLED, in that order', () => {
    expect(getAllowedTransitions('PENDING')).toEqual(['CONFIRMED', 'CANCELLED']);
  });

  it('CONFIRMED allows only SHIPPING', () => {
    expect(getAllowedTransitions('CONFIRMED')).toEqual(['SHIPPING']);
  });

  it('SHIPPING allows only DELIVERED', () => {
    expect(getAllowedTransitions('SHIPPING')).toEqual(['DELIVERED']);
  });

  it('DELIVERED is terminal — allows nothing', () => {
    expect(getAllowedTransitions('DELIVERED')).toEqual([]);
  });

  it('CANCELLED is terminal — allows nothing', () => {
    expect(getAllowedTransitions('CANCELLED')).toEqual([]);
  });

  it('covers exactly the five frozen statuses, no more, no less', () => {
    for (const status of ALL_STATUSES) {
      expect(() => getAllowedTransitions(status)).not.toThrow();
    }
  });
});

describe('requiresConfirmation', () => {
  it('is true only for CANCELLED', () => {
    for (const target of ALL_STATUSES) {
      expect(requiresConfirmation(target)).toBe(target === 'CANCELLED');
    }
  });
});

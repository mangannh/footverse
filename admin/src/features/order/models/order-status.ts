/** Lifecycle status of an order (dto-spec §4). Mirrors the frozen enum values. */
export type OrderStatus = 'PENDING' | 'CONFIRMED' | 'SHIPPING' | 'DELIVERED' | 'CANCELLED';

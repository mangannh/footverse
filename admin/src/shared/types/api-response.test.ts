import { describe, expect, it } from 'vitest';

import type { ApiResponse } from './api-response';

// Captured shapes of the frozen envelope (dto-spec §5): a success response, a
// business error (data null, errorCode present), and a validation failure
// (errors[]). These must type-check and round-trip through JSON unchanged.
describe('ApiResponse', () => {
  it('round-trips a success envelope', () => {
    const payload = {
      success: true,
      message: 'OK',
      data: { id: 1, name: 'Nike' },
      timestamp: '2026-01-01T00:00:00',
    };

    const envelope: ApiResponse<{ id: number; name: string }> = JSON.parse(JSON.stringify(payload));

    expect(envelope.success).toBe(true);
    expect(envelope.data).toEqual({ id: 1, name: 'Nike' });
    expect(envelope.errorCode).toBeUndefined();
    expect(envelope.errors).toBeUndefined();
  });

  it('round-trips a business-error envelope (null data, errorCode present)', () => {
    const payload = {
      success: false,
      message: 'Brand not found',
      data: null,
      errorCode: 'BRAND_NOT_FOUND',
      timestamp: '2026-01-01T00:00:00',
    };

    const envelope: ApiResponse<never> = JSON.parse(JSON.stringify(payload));

    expect(envelope.success).toBe(false);
    expect(envelope.data).toBeNull();
    expect(envelope.errorCode).toBe('BRAND_NOT_FOUND');
  });

  it('round-trips a validation envelope (field-level errors)', () => {
    const payload = {
      success: false,
      message: 'Validation failed',
      errorCode: 'VALIDATION_ERROR',
      errors: [{ field: 'name', message: 'must not be blank' }],
      timestamp: '2026-01-01T00:00:00',
    };

    const envelope: ApiResponse<never> = JSON.parse(JSON.stringify(payload));

    expect(envelope.errors).toEqual([{ field: 'name', message: 'must not be blank' }]);
  });
});

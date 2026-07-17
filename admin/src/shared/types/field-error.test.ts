import { describe, expect, it } from 'vitest';

import type { FieldError } from './field-error';

// Captured shape of the frozen field-level validation error (dto-spec §5).
describe('FieldError', () => {
  it('round-trips a field-level error', () => {
    const payload = { field: 'name', message: 'must not be blank' };

    const fieldError: FieldError = JSON.parse(JSON.stringify(payload));

    expect(fieldError).toEqual({ field: 'name', message: 'must not be blank' });
  });
});

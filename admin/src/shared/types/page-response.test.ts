import { describe, expect, it } from 'vitest';

import type { PageResponse } from './page-response';

// Captured shape of the frozen pagination wrapper (dto-spec §5). No Sprint 10
// endpoint returns a PageResponse yet (brand/category lists are unpaginated),
// but the shared type is part of the Task 01 envelope contract and must match
// field-for-field.
describe('PageResponse', () => {
  it('round-trips a page payload field-for-field', () => {
    const payload = {
      content: [{ id: 1, name: 'Nike' }],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    };

    const page: PageResponse<{ id: number; name: string }> = JSON.parse(JSON.stringify(payload));

    expect(page.content).toEqual([{ id: 1, name: 'Nike' }]);
    expect(page.page).toBe(0);
    expect(page.size).toBe(20);
    expect(page.totalElements).toBe(1);
    expect(page.totalPages).toBe(1);
    expect(page.last).toBe(true);
  });

  it('round-trips an empty page', () => {
    const payload = { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, last: true };

    const page: PageResponse<unknown> = JSON.parse(JSON.stringify(payload));

    expect(page.content).toEqual([]);
    expect(page.last).toBe(true);
  });
});

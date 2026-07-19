import { describe, expect, it } from 'vitest';

import { formatMonthLabel, toBarPercentages } from './dashboard-format';

describe('formatMonthLabel', () => {
  it('formats every one of the twelve months', () => {
    expect(formatMonthLabel(2026, 1)).toBe('Jan 2026');
    expect(formatMonthLabel(2026, 2)).toBe('Feb 2026');
    expect(formatMonthLabel(2026, 3)).toBe('Mar 2026');
    expect(formatMonthLabel(2026, 4)).toBe('Apr 2026');
    expect(formatMonthLabel(2026, 5)).toBe('May 2026');
    expect(formatMonthLabel(2026, 6)).toBe('Jun 2026');
    expect(formatMonthLabel(2026, 7)).toBe('Jul 2026');
    expect(formatMonthLabel(2026, 8)).toBe('Aug 2026');
    expect(formatMonthLabel(2026, 9)).toBe('Sep 2026');
    expect(formatMonthLabel(2026, 10)).toBe('Oct 2026');
    expect(formatMonthLabel(2026, 11)).toBe('Nov 2026');
    expect(formatMonthLabel(2026, 12)).toBe('Dec 2026');
  });

  it('carries the year across the year boundary — December of one year, January of the next', () => {
    expect(formatMonthLabel(2025, 12)).toBe('Dec 2025');
    expect(formatMonthLabel(2026, 1)).toBe('Jan 2026');
  });
});

describe('toBarPercentages', () => {
  it('converts a normal series to percentages of its maximum', () => {
    expect(toBarPercentages([50, 100, 25])).toEqual([50, 100, 25]);
  });

  it('returns an all-zero series when every value is zero — never divides by zero', () => {
    const result = toBarPercentages([0, 0, 0]);

    expect(result).toEqual([0, 0, 0]);
    expect(result.some((value) => Number.isNaN(value))).toBe(false);
  });

  it('handles a single-element series', () => {
    expect(toBarPercentages([42])).toEqual([100]);
    expect(toBarPercentages([0])).toEqual([0]);
  });

  it('handles an empty series without throwing or producing NaN', () => {
    expect(toBarPercentages([])).toEqual([]);
  });

  it('never produces NaN for any value in a mixed series', () => {
    const result = toBarPercentages([0, 10, 0, 20]);

    expect(result.every((value) => !Number.isNaN(value))).toBe(true);
    expect(result).toEqual([0, 50, 0, 100]);
  });
});

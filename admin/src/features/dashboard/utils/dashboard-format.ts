const MONTH_LABELS: readonly string[] = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/**
 * Formats a calendar year/month pair as a short, human-readable label (e.g.
 * `"Jul 2026"`) for the dashboard's monthly-revenue row (sprint-13-plan
 * Task 03). Pure and presentational only — it derives no figure and holds no
 * server data; `month` is 1–12, exactly the shape `MonthlyRevenueResponse`
 * carries.
 *
 * @param year  the calendar year
 * @param month the calendar month, 1–12
 * @return the formatted label
 */
export function formatMonthLabel(year: number, month: number): string {
  const label = MONTH_LABELS[month - 1] ?? String(month);
  return `${label} ${year}`;
}

/**
 * Converts a series of values to percentages of the series maximum, for the
 * dashboard's proportional monthly-revenue bars (sprint-13-plan Task 03,
 * Design Decision 9 — no charting library). Each value becomes
 * `(value / max) * 100`; when every value is `0` (an empty store, or a
 * window with no revenue at all), `max` is `0` and this returns an
 * all-zero series instead of dividing by zero — it never produces `NaN`.
 *
 * @param values the series to convert (never mutated)
 * @return one percentage per input value, in the same order
 */
export function toBarPercentages(values: readonly number[]): number[] {
  const max = Math.max(0, ...values);
  if (max === 0) {
    return values.map(() => 0);
  }
  return values.map((value) => (value / max) * 100);
}

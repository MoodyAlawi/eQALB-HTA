/**
 * Turning a post's date into the line a reader sees.
 *
 * A post writes its date as "YYYY-MM-DD" (see ../../content/blog/types.ts),
 * which is both the order the index sorts by and a valid `datetime` attribute
 * for the `<time>` element it is rendered in. This is only the readable half of
 * that.
 *
 * The format is fixed rather than locale-following, the way the rest of the
 * site's copy is: "1 October 2026" reads the same in every browser and needs no
 * translation. It is written out from UTC parts on purpose - a date in this blog
 * is a calendar date, not an instant, and parsing "2026-10-01" as local time
 * would show 30 September to a reader west of Greenwich.
 *
 * A date that is not a real "YYYY-MM-DD" date is shown exactly as it was
 * written, so a typo is visible on the page instead of quietly rendering as some
 * other day.
 */

const MONTHS = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
]

const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/

export function formatPostDate(date: string): string {
  const parts = DATE_PATTERN.exec(date)
  if (!parts) return date
  const [, year, month, day] = parts
  const monthIndex = Number(month) - 1
  const dayOfMonth = Number(day)
  if (monthIndex > 11) return date
  // Date.UTC rolls an impossible day (such as 2026-02-31) into the next month,
  // so the round trip is checked and the raw string kept when it does not match.
  const utc = new Date(Date.UTC(Number(year), monthIndex, dayOfMonth))
  if (utc.getUTCMonth() !== monthIndex || utc.getUTCDate() !== dayOfMonth) return date
  return `${dayOfMonth} ${MONTHS[monthIndex]} ${year}`
}

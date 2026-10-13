/**
 * CSV formatting and text download, shared by the per-tab exports and the
 * results package.
 *
 * No dependency is needed for this: every value is a number or a short string
 * that R already produced, so the helpers only quote and join. The quoting rule
 * matches `utils::write.csv()` — a cell is quoted only when it contains a
 * delimiter, a quote or a newline — and rows end with CRLF, which every
 * spreadsheet reads.
 *
 * No model logic lives here: nothing is computed, rescaled or interpreted.
 */

import { downloadBytes } from './zip'

/** One CSV cell: quoted only when it contains a delimiter, quote or newline. */
export function csvCell(value: unknown): string {
  if (value === null || value === undefined) return ''
  const text = typeof value === 'string' ? value : String(value)
  if (/[",\n\r]/.test(text)) return `"${text.replace(/"/g, '""')}"`
  return text
}

/** CSV text with a header row taken from the first row's keys. */
export function toCsv(rows: ReadonlyArray<object>): string {
  if (rows.length === 0) return ''
  const headers = Object.keys(rows[0])
  const lines = [headers.map(csvCell).join(',')]
  for (const row of rows) {
    const record = row as Record<string, unknown>
    lines.push(headers.map((header) => csvCell(record[header])).join(','))
  }
  return `${lines.join('\r\n')}\r\n`
}

/**
 * Two-column Measure/Value CSV, the shape the Shiny package uses for its summary
 * tables.
 */
export function measureValueCsv(rows: Array<[string, unknown]>): string {
  return toCsv(rows.map(([Measure, Value]) => ({ Measure, Value })))
}

/** Saves text to the user's downloads as the given file name. */
export function downloadText(
  text: string,
  filename: string,
  type = 'text/csv;charset=utf-8',
): void {
  downloadBytes(new TextEncoder().encode(text), filename, type)
}

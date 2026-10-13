/** Shared table contract. Kept out of DataTable.vue because `<script setup>`
 * blocks cannot export types. */

import type { Tone } from '../format'

export interface Column<R> {
  key: string
  label: string
  align?: 'left' | 'right'
  /** Cell text. Rows can return the not-interpretable dash themselves. */
  value: (row: R) => string
  /** Optional tone for the cell (saving/loss, cost-effective or not). */
  tone?: (row: R) => Tone | null | undefined
  /** Optional raw value for the title attribute (full precision). */
  title?: (row: R) => string | undefined
}

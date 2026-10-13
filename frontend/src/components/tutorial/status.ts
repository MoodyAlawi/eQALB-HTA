/**
 * Presentation mapping for a tutorial status.
 *
 * R decides the status; these helpers only decide which colour carries it and
 * are shared by the tutorial's cards and badges so the four steps cannot drift
 * apart. Every status is also written out as text beside the colour, so no
 * result is communicated by colour alone, and a status R did not assess keeps a
 * neutral treatment instead of picking a colour.
 */

import type { Tone } from '../../format'
import type { TutorialStatus } from '../../api/types'

export function statusCardClass(status: TutorialStatus): string {
  if (status === 'Green') return 'status-card status-card--good'
  if (status === 'Amber') return 'status-card status-card--warning'
  if (status === 'Red') return 'status-card status-card--bad'
  return 'status-card'
}

export function statusBadgeClass(status: TutorialStatus): string {
  if (status === 'Green') return 'badge badge--good'
  if (status === 'Amber') return 'badge badge--warning'
  if (status === 'Red') return 'badge badge--danger'
  return 'badge'
}

/** The metric accent for the same status. */
export function statusTone(status: TutorialStatus): Tone {
  if (status === 'Green') return 'good'
  if (status === 'Red') return 'bad'
  return 'neutral'
}

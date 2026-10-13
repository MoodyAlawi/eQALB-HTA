/**
 * The probability of cost-effectiveness at one threshold, read off the returned
 * acceptability curve — the chart's marker and the panel's information button
 * both state it, so both read it from here and neither estimates it.
 *
 * The curve's own point is used when the threshold is one of the returned
 * thresholds; a custom threshold is interpolated between the two neighbouring
 * thresholds, so the marker lands on the drawn curve. Nothing is derived from
 * the iteration cloud and no probability is re-computed.
 */

import type { CeacPoint } from '../../api/types'
import { isNum } from '../../format'

export function probabilityAtThreshold(ceac: readonly CeacPoint[], wtp: number): number | null {
  const exact = ceac.find((point) => Math.abs(point.wtp - wtp) < 1e-9)
  if (exact && isNum(exact.probability)) return exact.probability

  const usable = ceac.filter((point) => isNum(point.probability))
  if (usable.length === 0) return null
  const sorted = [...usable].sort((a, b) => a.wtp - b.wtp)
  const lower = [...sorted].reverse().find((point) => point.wtp <= wtp)
  const upper = sorted.find((point) => point.wtp >= wtp)
  if (!lower || !upper) return null
  if (upper.wtp === lower.wtp) return lower.probability
  const weight = (wtp - lower.wtp) / (upper.wtp - lower.wtp)
  return (lower.probability as number) * (1 - weight) + (upper.probability as number) * weight
}

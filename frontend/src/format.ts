/**
 * Presentation helpers.
 *
 * Costs are shown in EUR and effects in QALYs, per the project conventions.
 * The R layer returns JSON `null` when a value is not interpretable (an ICER of
 * infinity, a median that is never reached). This module is the single place
 * that decides how to render that: a dash, never "NaN" and never "0".
 */

/** Shown instead of a number the model could not compute. */
export const NOT_INTERPRETABLE = '—'

/** Accepts `undefined` too, so an unfilled input reads as "not interpretable". */
type MaybeNumber = number | null | undefined

export function isNum(value: MaybeNumber): value is number {
  return typeof value === 'number' && Number.isFinite(value)
}

const euroFormatter = (digits: number) =>
  new Intl.NumberFormat('en-IE', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  })

const numberFormatters = new Map<number, Intl.NumberFormat>()

function numberFormatter(digits: number): Intl.NumberFormat {
  let formatter = numberFormatters.get(digits)
  if (!formatter) {
    formatter = new Intl.NumberFormat('en-IE', {
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    })
    numberFormatters.set(digits, formatter)
  }
  return formatter
}

/** Costs in EUR, e.g. €2,439 or €2,439.28. */
export function formatEuro(value: MaybeNumber, digits = 0): string {
  return isNum(value) ? euroFormatter(digits).format(value) : NOT_INTERPRETABLE
}

/** Effects in QALYs (four decimals by default, as the ratios are small). */
export function formatQaly(value: MaybeNumber, digits = 4): string {
  return isNum(value) ? numberFormatter(digits).format(value) : NOT_INTERPRETABLE
}

/** A fraction (0.1) as a percentage ("10.0%"). */
export function formatPercent(value: MaybeNumber, digits = 1): string {
  return isNum(value) ? `${numberFormatter(digits).format(value * 100)}%` : NOT_INTERPRETABLE
}

export function formatNumber(value: MaybeNumber, digits = 0): string {
  return isNum(value) ? numberFormatter(digits).format(value) : NOT_INTERPRETABLE
}

/** Counts of people, with thousands separators. */
export function formatCount(value: MaybeNumber, digits = 0): string {
  return formatNumber(value, digits)
}

/** Euro per QALY pairs, e.g. €100,000/QALY. */
export function formatThreshold(value: MaybeNumber): string {
  return isNum(value) ? `${formatEuro(value)}/QALY` : NOT_INTERPRETABLE
}

/** Short euro label for chart axes: €2.4k, €1.2m. */
export function formatEuroCompact(value: MaybeNumber): string {
  if (!isNum(value)) return NOT_INTERPRETABLE
  const absolute = Math.abs(value)
  if (absolute >= 1_000_000) return `€${formatNumber(value / 1_000_000, 1)}m`
  if (absolute >= 1_000) return `€${formatNumber(value / 1_000, 0)}k`
  return `€${formatNumber(value, 0)}`
}

/**
 * The ICER is a ratio and is only meaningful when the model is cost-effective
 * at the threshold or when it is dominated. R returns null for an infinite or
 * undefined ratio, and this helper explains both cases in plain language.
 */
export function describeIcer(
  icer: MaybeNumber,
  incrementalCost: MaybeNumber,
  incrementalQalys: MaybeNumber,
): string {
  if (isNum(icer)) return formatEuro(icer)
  if (isNum(incrementalQalys) && incrementalQalys <= 0 && isNum(incrementalCost) && incrementalCost > 0) {
    return 'Dominated (costs more, no extra QALYs)'
  }
  if (isNum(incrementalQalys) && incrementalQalys > 0) {
    return 'Not interpretable'
  }
  return NOT_INTERPRETABLE
}

/** A decision label with the traffic-light tone used across the app. */
export type Tone = 'good' | 'bad' | 'neutral'

export function costEffectivenessTone(costEffective: boolean | null): Tone {
  if (costEffective === null) return 'neutral'
  return costEffective ? 'good' : 'bad'
}

export function costEffectivenessLabel(costEffective: boolean | null, threshold: MaybeNumber): string {
  if (costEffective === null) return 'Not interpretable'
  return costEffective
    ? `Cost-effective at ${formatThreshold(threshold)}`
    : `Not cost-effective at ${formatThreshold(threshold)}`
}

export function formatDateRange(years: number): string {
  return `${formatNumber(years, 0)} years`
}

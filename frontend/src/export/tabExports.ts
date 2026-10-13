/**
 * Per-tab CSV exports.
 *
 * Each builder formats values that an API response already contains; none of
 * them computes, rescales or interprets a model result. Where the Shiny app has
 * an equivalent download the file keeps Shiny's shape, and where it does not the
 * file says so in its name and on the tab, because an export that looks like
 * Shiny's but carries different columns is worse than no export.
 *
 * Shiny's per-tab downloads, for reference (app.R):
 *   - cost-effectiveness: long form section/parameter/value/unit, written by
 *     ce_export_results() — reproduced here row for row.
 *   - sensitivity analysis: the long, one-row-per-scenario owsa_result() table.
 *     The API returns the ranked table instead (one row per parameter with its
 *     low and high values), so this export is named differently and the tab says
 *     what the columns are.
 *   - Kaplan-Meier: the simulated patient-level dataset, which no endpoint
 *     returns. This export carries the summary tables the tab displays, under a
 *     name that says so.
 *   - the rendered charts (PNG/PDF) and the patient-level dataset need new
 *     server-side work; see backendGap() and the tabs.
 */

import type { BaseCaseResponse, OwsaResponse, SurvivalResponse } from '../api/types'
import { toCsv } from './csv'
import { formatCount, formatNumber, isNum } from '../format'

/**
 * The nine model inputs Shiny writes into its cost-effectiveness export, with
 * Shiny's own labels and units (app.R, ce_export_results()). The values are read
 * from the response, so only the presentation strings are repeated here.
 */
const BASE_CASE_INPUTS: ReadonlyArray<readonly [string, string, string]> = [
  ['intervention_price', 'Annual intervention price', 'EUR/person/year'],
  ['implementation_cost', 'Implementation cost', 'EUR/person'],
  ['healthcare_savings', 'Annual healthcare-use savings', 'EUR/person/year'],
  ['rrr', 'Relative risk reduction', 'proportion'],
  ['engagement_year1', 'Year-1 engagement', 'proportion'],
  ['engagement_followup', 'Follow-up engagement', 'proportion'],
  ['utility_no_event', 'Utility: no event', 'utility'],
  ['utility_post_mi', 'Utility: post-MI', 'utility'],
  ['utility_post_stroke', 'Utility: post-stroke', 'utility'],
]

interface BaseCaseCsvRow {
  section: string
  parameter: string
  value: unknown
  unit: string
}

/**
 * The base case in Shiny's `eqalb_cost_effectiveness_results.csv` layout: the
 * nine model inputs, then the three headline results. A value R could not
 * compute (a non-estimable ICER) is an empty cell, where Shiny writes NA.
 */
export function baseCaseCsv(result: BaseCaseResponse): string {
  const rows: BaseCaseCsvRow[] = BASE_CASE_INPUTS.map(([id, parameter, unit]) => ({
    section: 'Model input',
    parameter,
    value: result.inputs[`scenario_${id}`] ?? null,
    unit,
  }))
  rows.push(
    {
      section: 'Model result',
      parameter: 'Incremental cost',
      value: result.incremental_cost,
      unit: 'EUR/person',
    },
    {
      section: 'Model result',
      parameter: 'Incremental QALYs',
      value: result.incremental_qalys,
      unit: 'QALYs/person',
    },
    { section: 'Model result', parameter: 'ICER', value: result.icer, unit: 'EUR/QALY' },
  )
  return toCsv(rows)
}

/**
 * The one-way sensitivity analysis as the API returns it: one row per parameter,
 * with the low and high scenario results in columns. This is the table the tab
 * displays, so the file and the screen cannot disagree.
 */
export function owsaCsv(result: OwsaResponse): string {
  return toCsv(result.table)
}

interface KmCsvRow {
  section: string
  arm: string
  year: number | ''
  measure: string
  value: unknown
}

/** "not reached" for a median the simulation never crossed, as the tab shows it. */
function medianText(value: number | null): string {
  return isNum(value) ? formatNumber(value, 2) : 'not reached'
}

/**
 * The Kaplan-Meier tables the survival tab displays — the arm summary, the
 * number at risk by year, the arm-contrast checks and the modelled expectation —
 * in one tidy file. It is deliberately not named like Shiny's export: Shiny
 * writes the simulated patient-level dataset, which no endpoint returns.
 */
export function kmSummaryCsv(result: SurvivalResponse): string {
  const rows: KmCsvRow[] = []

  for (const arm of result.summary) {
    const measures: Array<[string, unknown]> = [
      ['Patients enrolled', arm.patients_enrolled],
      ['Composite cardiovascular events', arm.events],
      ['Censored (total)', arm.censored],
      ['Median event-free survival (years)', medianText(arm.median_event_free_survival_years)],
      ['Event-free at 1 year', arm.event_free_at_1_year],
      ['Event-free at 5 years', arm.event_free_at_5_years],
      ['Event-free at 10 years', arm.event_free_at_10_years],
    ]
    for (const [measure, value] of measures) {
      rows.push({ section: 'Arm summary', arm: arm.treatment, year: '', measure, value })
    }
  }

  for (const row of result.risk_table) {
    rows.push({
      section: 'Number at risk',
      arm: row.treatment,
      year: row.year,
      measure: 'Number at risk',
      value: row.at_risk,
    })
  }

  for (const check of result.arm_contrast.checks) {
    rows.push({
      section: 'Interpretation checks',
      arm: '',
      year: '',
      measure: check.Check,
      value: check.Finding,
    })
  }

  for (const [arm, expected] of Object.entries(result.expected_events)) {
    const drawn = result.summary.find((row) => row.treatment === arm)?.events ?? null
    rows.push({
      section: 'Modelled expectation',
      arm,
      year: '',
      measure: 'Composite events (modelled expectation)',
      value: isNum(expected) ? formatNumber(expected, 1) : null,
    })
    rows.push({
      section: 'Modelled expectation',
      arm,
      year: '',
      measure: 'Composite events (simulation draws)',
      value: formatCount(drawn),
    })
  }

  return toCsv(rows)
}

/** The file names, kept next to the builders so they cannot drift apart. */
export const EXPORT_FILENAMES = {
  baseCase: 'eqalb_cost_effectiveness_results.csv',
  owsa: 'eqalb_owsa_ranked_table.csv',
  km: 'eqalb_km_summary_tables.csv',
} as const

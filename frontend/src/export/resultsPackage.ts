/**
 * The download-results package, built in the browser from results this session
 * already holds.
 *
 * The Shiny app builds a ZIP from its reactives with R's write_results_package().
 * The Vue client cannot call that function (it lives in app.R, which the API
 * deliberately does not source), so this module assembles the same kind of
 * package from the API responses already in the store. It only formats values
 * that R produced — it never recomputes, adjusts or interprets a result — and an
 * analysis that has not been run contributes no file, exactly as in Shiny.
 *
 * What it therefore cannot include is the rendered chart images (the
 * cost-effectiveness plane, CEAC, tornado, budget-impact plot and Kaplan-Meier
 * curve), which Shiny draws with R graphics; see backendGap() for the precise
 * remaining work.
 */

import { useModel } from '../composables/useModel'
import { formatCount, formatEuro, formatPercent, isNum } from '../format'
import { toCsv } from './csv'

export interface PackageFile {
  name: string
  text: string
}

export interface AnalysisAvailability {
  /** Name shown in the UI and repeated in the README. */
  label: string
  included: boolean
  /** What to run to include it, in the wording the analysis tab uses. */
  hint: string
}

export interface ResultsPackage {
  files: PackageFile[]
  included: string[]
  missing: string[]
  availability: AnalysisAvailability[]
}

/** Precise description of the export parity that is still missing. */
export function backendGap(): string {
  return (
    'The Shiny package also contains rendered chart images (cost-effectiveness plane, CEAC, ' +
    'tornado diagram, budget-impact plot and Kaplan-Meier curve) produced by R graphics. ' +
    'Producing those in the browser interface needs new server-side work: an API endpoint that ' +
    'renders a plot from the results already held by the client, reusing the existing R plotting ' +
    'code in app.R (write_plot_png) or a plot function moved into the model modules. Until that ' +
    'exists, this package carries the underlying numeric tables instead, so no result is invented ' +
    'and nothing available is silently dropped.'
  )
}

// --- CSV helpers -------------------------------------------------------------

/** Two-column Measure/Value CSV, the shape the Shiny package uses. */
function measureValue(rows: Array<[string, unknown]>): string {
  return toCsv(rows.map(([Measure, Value]) => ({ Measure, Value })))
}

// --- Timestamps --------------------------------------------------------------

function pad(value: number): string {
  return String(value).padStart(2, '0')
}

/** "2026-10-10 05:30:00", matching the Shiny README header. */
export function packageTimestamp(now: Date = new Date()): string {
  return (
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ` +
    `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`
  )
}

/** "eqalb_results_2026-10-10_0530.zip", matching the Shiny file name. */
export function packageFilename(now: Date = new Date()): string {
  return (
    `eqalb_results_${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_` +
    `${pad(now.getHours())}${pad(now.getMinutes())}.zip`
  )
}

// --- Availability ------------------------------------------------------------

const ANALYSIS_LABELS = {
  baseCase: 'Base-case cost-effectiveness (model assumptions and cost-effectiveness summary)',
  psa: 'Probabilistic sensitivity analysis (PSA summary and probabilities at each threshold)',
  owsa: 'Deterministic one-way sensitivity analysis (tornado table)',
  budget: 'Five-year budget-impact analysis',
  survival: 'Kaplan-Meier simulation (simulated illustrative data)',
  voi: 'Value of information (EVPI and EVPPI per patient, from the PSA draws)',
  readiness: 'DHT readiness and implementation assessment',
  hta: 'HTA decision summary and evidence priorities',
  valueBasedPrice:
    'Value-based price (supported annual price, headroom, required effect and the 3 x 3 scan)',
} as const

const ANALYSIS_HINTS = {
  baseCase: 'Run base case in the Base case tab',
  psa: 'Run PSA in the Cost-effectiveness and PSA tab',
  owsa: 'Run sensitivity analysis in the Sensitivity analysis tab',
  budget: 'Run budget impact in the Budget impact tab',
  survival: 'Run survival simulation in the Simulated survival tab',
  voi: 'Run the PSA, then value of information in the Value of information tab',
  readiness: 'Assess readiness in the DHT readiness tab',
  hta: 'Assess HTA summary in the HTA Decision Summary tab',
  valueBasedPrice: 'Calculate value-based price in the Value-based Price tab',
} as const

/**
 * Which analyses this session has produced. Read straight off the store, so the
 * list cannot disagree with what the tabs are showing.
 */
export function analysisAvailability(): AnalysisAvailability[] {
  const model = useModel()
  const present: Record<keyof typeof ANALYSIS_LABELS, boolean> = {
    baseCase: model.baseCase !== null,
    psa: model.psa !== null,
    owsa: model.owsa !== null,
    budget: model.budget !== null,
    survival: model.survival !== null,
    voi: model.voi !== null,
    readiness: model.readiness !== null,
    hta: model.htaSummary !== null,
    valueBasedPrice: model.valueBasedPrice !== null,
  }
  return (Object.keys(ANALYSIS_LABELS) as Array<keyof typeof ANALYSIS_LABELS>).map((key) => ({
    label: ANALYSIS_LABELS[key],
    included: present[key],
    hint: ANALYSIS_HINTS[key],
  }))
}

// --- The package -------------------------------------------------------------

export function buildResultsPackage(now: Date = new Date()): ResultsPackage {
  const model = useModel()
  const files: PackageFile[] = []
  const included: string[] = []
  const missing: string[] = []
  const availability = analysisAvailability()

  const add = (name: string, text: string): void => {
    files.push({ name, text })
  }

  // Base-case cost-effectiveness -------------------------------------------------
  const base = model.baseCase
  if (base) {
    const rows = Object.entries(base.inputs).map(([input, value]) => ({ input, value }))
    add('model_assumptions.csv', toCsv(rows))
    add(
      'cost_effectiveness_summary.csv',
      measureValue([
        ['Incremental cost (EUR per person)', base.incremental_cost],
        ['Incremental QALYs (per person)', base.incremental_qalys],
        ['ICER (EUR per QALY)', base.icer],
      ]),
    )
    included.push(ANALYSIS_LABELS.baseCase)
  } else {
    missing.push(`Base-case cost-effectiveness - ${ANALYSIS_HINTS.baseCase.toLowerCase()}`)
  }

  // Probabilistic sensitivity analysis ------------------------------------------
  const psa = model.psa
  if (psa) {
    const probabilityRows = Object.entries(psa.probability_cost_effective).map(
      ([threshold, probability]) => [
        `Probability cost-effective at EUR ${threshold} per QALY`,
        isNum(probability) ? formatPercent(probability, 1) : 'Not interpretable',
      ] as [string, unknown],
    )
    add(
      'psa_summary.csv',
      measureValue([
        ['Simulations requested', psa.n_requested],
        ['Successful simulations', psa.n_successful],
        ['Failed simulations', psa.n_failed],
        ['PSA random seed (recorded when the PSA was last run)', psa.seed],
        ['Mean incremental cost (EUR per person)', psa.mean_incremental_cost],
        ['Mean incremental QALYs (per person)', psa.mean_incremental_qalys],
        ['Median ICER (EUR per QALY, where interpretable)', psa.median_icer],
        ...probabilityRows,
      ]),
    )
    included.push(ANALYSIS_LABELS.psa)
  } else {
    missing.push(`Probabilistic sensitivity analysis - ${ANALYSIS_HINTS.psa.toLowerCase()}`)
  }

  // One-way sensitivity analysis -------------------------------------------------
  const owsa = model.owsa
  if (owsa) {
    add('owsa_results.csv', toCsv(owsa.table))
    included.push(ANALYSIS_LABELS.owsa)
  } else {
    missing.push(`Deterministic one-way sensitivity analysis - ${ANALYSIS_HINTS.owsa.toLowerCase()}`)
  }

  // Budget impact ----------------------------------------------------------------
  const budget = model.budget
  if (budget) {
    add('budget_impact_results.csv', toCsv(budget.table))
    included.push(ANALYSIS_LABELS.budget)
  } else {
    missing.push(`Five-year budget-impact analysis - ${ANALYSIS_HINTS.budget.toLowerCase()}`)
  }

  // Simulated survival -----------------------------------------------------------
  const survival = model.survival
  if (survival) {
    add('km_results.csv', toCsv(survival.summary))
    included.push(ANALYSIS_LABELS.survival)
  } else {
    missing.push(`Kaplan-Meier simulation - ${ANALYSIS_HINTS.survival.toLowerCase()}`)
  }

  // DHT readiness -----------------------------------------------------------------
  const readiness = model.readiness
  if (readiness) {
    const numbers = readiness.numbers.map((row) => ({
      Section: 'Quantitative output',
      Item: row.Measure,
      Status: '',
      Value: row.Value,
      Basis: row['Illustrative basis'],
    }))
    const domains = readiness.domains.map((row) => ({
      Section: 'Readiness domain',
      Item: row.Domain,
      Status: row.Status,
      Value: row['Current input'],
      Basis: row.Interpretation,
    }))
    add('dht_readiness_results.csv', toCsv([...numbers, ...domains]))
    included.push(ANALYSIS_LABELS.readiness)
  } else {
    missing.push(`DHT readiness and implementation assessment - ${ANALYSIS_HINTS.readiness.toLowerCase()}`)
  }

  // HTA decision summary and evidence priorities ------------------------------------
  const hta = model.htaSummary
  if (hta) {
    const lines: string[] = [
      'eQalb HTA Learning Model - HTA decision summary',
      `Exported: ${packageTimestamp(now)}`,
      '',
      `Overall status: ${hta.summary.overall_status}`,
      `Provisional HTA position: ${hta.summary.position}`,
      '',
      'Dashboard domains',
      '-----------------',
    ]
    for (const domain of hta.summary.domains) {
      lines.push(
        `Domain: ${domain.Domain}`,
        `  Status: ${domain.Status}`,
        `  Measure: ${domain.Measure}`,
        `  Basis: ${domain.Basis}`,
        `  Interpretation: ${domain.Interpretation}`,
        '',
      )
    }
    lines.push(
      'Plain-language interpretation',
      '-----------------------------',
      hta.summary.interpretation,
      '',
      'Evidence priorities',
      '-------------------',
      hta.evidence_priorities.summary,
    )
    add('hta_decision_summary.txt', `${lines.join('\n')}\n`)
    add('evidence_priorities.csv', toCsv(hta.evidence_priorities.table))
    included.push(ANALYSIS_LABELS.hta)
  } else {
    missing.push(`HTA decision summary and evidence priorities - ${ANALYSIS_HINTS.hta.toLowerCase()}`)
  }

  // Value of information ----------------------------------------------------------
  const voi = model.voi
  if (voi) {
    const lines: string[] = [
      'eQalb HTA Learning Model - value of information',
      `Exported: ${packageTimestamp(now)}`,
      '',
      `Reference threshold: EUR ${formatCount(voi.wtp, 0)} per QALY`,
      `PSA draws used: ${formatCount(voi.n)}`,
      '',
      'Expected value of perfect information (per patient)',
      '--------------------------------------------------',
      `EVPI: ${isNum(voi.evpi.evpi) ? formatEuro(voi.evpi.evpi, 2) : 'Not interpretable'}`,
      `Mean incremental cost: ${formatEuro(voi.evpi.mean_incremental_cost, 2)}`,
      `Mean incremental QALYs: ${voi.evpi.mean_incremental_qalys ?? 'Not interpretable'}`,
      `Mean incremental net monetary benefit: ${formatEuro(voi.evpi.mean_nmb, 2)}`,
      `Expected NMB with perfect information: ${formatEuro(voi.evpi.expected_nmb_perfect, 2)}`,
      `Expected NMB with current information: ${formatEuro(voi.evpi.expected_nmb_current, 2)}`,
      '',
      'Expected value of partial perfect information (per patient)',
      '----------------------------------------------------------',
    ]
    if (voi.evppi.available) {
      for (const row of voi.evppi.table) {
        lines.push(
          `${row.parameter} (${row.model_argument}): ` +
            `${isNum(row.evppi) ? formatEuro(row.evppi, 2) : 'Not interpretable'}` +
            `${row.clamped ? ' (clamped to zero)' : ''}`,
        )
      }
    } else {
      lines.push(`Not available: ${voi.evppi.reason}`)
    }
    add('value_of_information.txt', `${lines.join('\n')}\n`)
    if (voi.evppi.available) {
      add('evppi_by_parameter.csv', toCsv(voi.evppi.table))
    }
    included.push(ANALYSIS_LABELS.voi)
  } else {
    missing.push(`Value of information - ${ANALYSIS_HINTS.voi.toLowerCase()}`)
  }

  // Value-based price -------------------------------------------------------------
  const valueBasedPrice = model.valueBasedPrice
  if (valueBasedPrice) {
    const headline = valueBasedPrice.headline
    const required = valueBasedPrice.required_effect
    const grid = valueBasedPrice.grid
    const lines: string[] = [
      'eQalb HTA Learning Model - value-based price',
      `Exported: ${packageTimestamp(now)}`,
      '',
      `Reference threshold: EUR ${formatCount(valueBasedPrice.wtp, 0)} per QALY`,
      `Current annual price: ${formatEuro(valueBasedPrice.current_price, 2)} per active user per year`,
      `R method: ${valueBasedPrice.method}`,
      '',
      'Supported price',
      '---------------',
      `Maximum acceptable annual price: ${
        isNum(headline.max_acceptable_price)
          ? formatEuro(headline.max_acceptable_price, 2)
          : 'Not available'
      }`,
      `R status band for the current price: ${valueBasedPrice.status}`,
      `Headroom against the current price: ${formatEuro(headline.headroom_eur, 2)}`,
      `Headroom as a percentage of the current price: ${
        isNum(headline.headroom_pct) ? formatPercent(headline.headroom_pct / 100, 1) : 'Not available'
      }`,
      `Model cost response to the annual price (EUR per EUR): ${headline.price_cost_slope ?? ''}`,
      `Incremental cost at an annual price of zero: ${formatEuro(headline.cost_without_price, 2)}`,
      `Confirming run's incremental net monetary benefit: ${headline.verification_nmb ?? ''}`,
      `Raw solved price: ${formatEuro(headline.solved_price, 2)}`,
      '',
      'Required relative risk reduction',
      '--------------------------------',
      `Available: ${required.available ? 'yes' : 'no'}`,
      `R verdict: ${required.verdict}`,
      `Required reduction among engaged users: ${
        isNum(required.required_rrr_pct) ? formatPercent(required.required_rrr_pct / 100, 1) : 'Not available'
      }`,
      `Assumed in this scenario: ${
        isNum(required.current_rrr_pct) ? formatPercent(required.current_rrr_pct / 100, 1) : 'Not available'
      }`,
      `Inside the model's one-way range for this input: ${
        required.within_sensitivity_range === null
          ? 'Not available'
          : required.within_sensitivity_range
            ? 'yes'
            : 'no'
      }`,
      required.reason ? `R's reason: ${required.reason}` : '',
      '',
      'Illustrative 3 x 3 scan',
      '-----------------------',
      `Rows: ${grid.row_axis.parameter}; columns: ${grid.column_axis.parameter}`,
      `Combinations R identified: ${formatCount(grid.cells_available)} of ${formatCount(grid.cells_total)}`,
      `Combinations supporting the current annual price: ${formatCount(grid.cells_supporting_current_price)}`,
      '',
      grid.summary,
      '',
      grid.note,
      '',
      "R's interpretation",
      '------------------',
      valueBasedPrice.interpretation,
      '',
      'Availability',
      '------------',
      `Maximum acceptable price: ${
        valueBasedPrice.availability.max_acceptable_price ? 'identified' : 'not available'
      }`,
      `Required relative risk reduction: ${
        valueBasedPrice.availability.required_effect ? 'identified' : 'not available'
      }`,
      `Scan: ${valueBasedPrice.availability.grid ? 'every combination identified' : 'partly identified'}`,
      valueBasedPrice.availability.reasons.max_acceptable_price
        ? `Maximum acceptable price reason: ${valueBasedPrice.availability.reasons.max_acceptable_price}`
        : '',
      valueBasedPrice.availability.reasons.required_effect
        ? `Required relative risk reduction reason: ${valueBasedPrice.availability.reasons.required_effect}`
        : '',
      valueBasedPrice.availability.reasons.grid
        ? `Scan reason: ${valueBasedPrice.availability.reasons.grid}`
        : '',
      '',
      valueBasedPrice.method_note,
    ].filter((line) => line !== '')
    add('value_based_price.txt', `${lines.join('\n')}\n`)
    add('value_based_price_scan.csv', toCsv(grid.cells))
    included.push(ANALYSIS_LABELS.valueBasedPrice)
  } else {
    missing.push(`Value-based price - ${ANALYSIS_HINTS.valueBasedPrice.toLowerCase()}`)
  }

  // README ------------------------------------------------------------------------
  const psaLines = psa
    ? [
        `PSA random seed (recorded when the PSA was last run): ${formatCount(psa.seed)}`,
        `PSA simulations in the exported results: ${formatCount(psa.n_requested)} requested, ` +
          `${formatCount(psa.n_successful)} successful and ${formatCount(psa.n_failed)} failed.`,
      ]
    : [
        'PSA seed and number of simulations: not available, because the probabilistic',
        'analysis has not been run in this session.',
      ]

  const readme = [
    'eQalb HTA Learning Model - results package',
    '==============================================================',
    '',
    'App: eQalb HTA Learning Model (browser interface over the eQalb R model)',
    `Exported: ${packageTimestamp(now)}`,
    '',
    'IMPORTANT',
    '---------',
    'Every output in this package is a simulated, illustrative result of an',
    'educational teaching model for a fictional digital therapeutic. None of it is',
    'clinical evidence, a validated health-technology assessment, or a regulatory,',
    'security or reimbursement assessment.',
    '',
    'Comparator and usual-care cost assumption',
    '----------------------------------------',
    'Usual care is the comparator arm, and the model is an incremental comparison',
    'between eQalb plus usual care and usual care alone. Routine-care, medication,',
    'monitoring and visit costs that are assumed identical in both arms are omitted,',
    'so no routine-care cost line appears in either arm; this is a modelling',
    'assumption, not an estimate that usual care costs nothing. Event-related post-MI',
    'and post-stroke state costs are included in both arms and differ only through',
    'the health-state occupancy each arm produces.',
    '',
    'PSA seed and number of simulations',
    '---------------------------------',
    ...psaLines,
    '',
    'Analyses included in this package',
    '--------------------------------',
    included.length === 0 ? '-- none' : included.map((line) => `- ${line}`).join('\n'),
    '',
    'Analyses that had not been run in this session (no file included)',
    '----------------------------------------------------------------',
    missing.length === 0 ? '-- none: every analysis was available' : missing.map((line) => `- ${line}`).join('\n'),
    '',
    'Files in this package',
    '---------------------',
    ...['README.txt', ...files.map((file) => file.name)].map((name) => `- ${name}`),
    '',
    'Difference from the Shiny results package',
    '----------------------------------------',
    backendGap(),
    '',
    'Where the numbers come from',
    '---------------------------',
    'Every value in this package was produced by the eQalb R model and returned by',
    'the model API. The browser interface formats those values for a file; it does',
    'not calculate, adjust or interpret any result.',
    '',
  ].join('\n')

  return {
    files: [{ name: 'README.txt', text: readme }, ...files],
    included,
    missing,
    availability,
  }
}

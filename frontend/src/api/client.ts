/**
 * Typed client for the eQalb model API (FastAPI in ../api, fanning out to the
 * R model). This module only transports requests: it never computes, defaults
 * or validates model values, because the R layer owns all of that. A rejected
 * input comes back as an ApiError carrying the R error message verbatim.
 *
 * In development the Vite dev server proxies /api to http://127.0.0.1:8788
 * (see vite.config.ts), so the browser stays on one origin.
 */

import type {
  BaseCaseResponse,
  BudgetImpactResponse,
  DefaultsResponse,
  HealthResponse,
  HtaSummaryInputs,
  HtaSummaryResponse,
  OwsaDefaultsResponse,
  OwsaOutcome,
  OwsaRangeOverride,
  OwsaResponse,
  Part2CaseResponse,
  Part2Curve,
  Part2EvaluateResponse,
  PsaResponse,
  ReadinessInputs,
  ReadinessResponse,
  ScenarioInputs,
  SurvivalResponse,
  TutorialInputs,
  TutorialPart1Response,
  TutorialPart2ContractResponse,
  TutorialResponse,
  ValueBasedPriceResponse,
  VoiResponse,
} from './types'

const BASE_URL = import.meta.env.VITE_API_BASE ?? '/api'

/** Query values are sent as strings; the R layer parses and validates them. */
export type Query = Record<string, string | number>

export class ApiError extends Error {
  readonly status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }

  /** True when the service could not be reached at all. */
  get isOffline(): boolean {
    return this.status === 0
  }
}

function buildUrl(path: string, query?: Query): string {
  const url = `${BASE_URL}${path}`
  if (!query || Object.keys(query).length === 0) return url
  const search = new URLSearchParams()
  for (const [key, value] of Object.entries(query)) {
    // An emptied or non-numeric control must not send "NaN" to R: skipping it
    // lets the R layer apply its own default instead.
    if (value === undefined || value === null || value === '') continue
    if (typeof value === 'number' && !Number.isFinite(value)) continue
    search.set(key, String(value))
  }
  const queryString = search.toString()
  return queryString ? `${url}?${queryString}` : url
}

async function request<T>(path: string, query?: Query, body?: unknown): Promise<T> {
  let response: Response
  try {
    response = await fetch(buildUrl(path, query), {
      method: body === undefined ? 'GET' : 'POST',
      headers: body === undefined ? undefined : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiError(
      'Cannot reach the model service. Check that it is running, then try again.',
      0,
    )
  }

  const text = await response.text()
  let payload: unknown = null
  if (text) {
    try {
      payload = JSON.parse(text)
    } catch {
      payload = text
    }
  }

  if (!response.ok) {
    throw new ApiError(describeError(payload, response.status), response.status)
  }
  return payload as T
}

/** FastAPI reports problems as `detail`; the R message comes through verbatim. */
function describeError(payload: unknown, status: number): string {
  if (payload && typeof payload === 'object' && 'detail' in payload) {
    const detail = (payload as { detail: unknown }).detail
    if (typeof detail === 'string') return detail
    if (Array.isArray(detail)) {
      // FastAPI's own validation errors are lists of {loc, msg}.
      return detail
        .map((item) => {
          const entry = item as { loc?: unknown[]; msg?: string }
          const location = Array.isArray(entry.loc) ? entry.loc.slice(1).join('.') : ''
          return location ? `${location}: ${entry.msg ?? ''}` : (entry.msg ?? '')
        })
        .filter(Boolean)
        .join('; ')
    }
  }
  if (typeof payload === 'string' && payload.trim()) return payload.trim()
  return `The model API returned HTTP ${status}.`
}

export function fetchHealth(): Promise<HealthResponse> {
  return request<HealthResponse>('/health')
}

export function fetchDefaults(): Promise<DefaultsResponse> {
  return request<DefaultsResponse>('/defaults')
}

export function postBaseCase(
  inputs: Partial<ScenarioInputs>,
  wtp: number,
): Promise<BaseCaseResponse> {
  return request<BaseCaseResponse>('/base-case', { wtp }, inputs)
}

export function postPsa(
  inputs: Partial<ScenarioInputs>,
  options: { nSim: number; seed: number; wtp: number },
): Promise<PsaResponse> {
  return request<PsaResponse>(
    '/psa',
    { n_sim: options.nSim, seed: options.seed, wtp: options.wtp },
    inputs,
  )
}

/**
 * One range row as the request bodies carry it: the parameter R derives a range
 * for, and the absolute values the user set for it. R validates them.
 */
function rangeOverrides(bounds?: OwsaRangeOverride[]): Array<{ id: string; low: number; high: number }> {
  return (bounds ?? []).map((bound) => ({
    id: bound.id,
    low: bound.low,
    high: bound.high,
  }))
}

export function postOwsa(
  inputs: Partial<ScenarioInputs>,
  options: { outcome: OwsaOutcome; wtp: number; bounds?: OwsaRangeOverride[] },
): Promise<OwsaResponse> {
  const body: Record<string, unknown> = { ...inputs }
  const bounds = rangeOverrides(options.bounds)
  if (bounds.length > 0) body.bounds = bounds
  return request<OwsaResponse>('/owsa', { outcome: options.outcome, wtp: options.wtp }, body)
}

/**
 * The one-way ranges R derives for a scenario, without running the analysis. An
 * editor uses it to show the ranges that are in force for the assumptions in the
 * form; the ranges R cannot use come back on their row with R's own sentence.
 */
export function postOwsaDefaults(
  inputs: Partial<ScenarioInputs>,
  bounds?: OwsaRangeOverride[],
): Promise<OwsaDefaultsResponse> {
  const body: Record<string, unknown> = { ...inputs }
  const overrides = rangeOverrides(bounds)
  if (overrides.length > 0) body.bounds = overrides
  return request<OwsaDefaultsResponse>('/owsa-defaults', undefined, body)
}

export interface BudgetImpactOptions {
  population: number
  year1UptakePct: number
  annualUptakeIncreasePp: number
  horizonYears: number
  avoidedEventSavingsPerActiveUser: number
  followupEngagementPct?: number
}

export function postBudgetImpact(
  inputs: Partial<ScenarioInputs>,
  options: BudgetImpactOptions,
): Promise<BudgetImpactResponse> {
  const body: Record<string, unknown> = {
    ...inputs,
    population: options.population,
    year1_uptake_pct: options.year1UptakePct,
    annual_uptake_increase_pp: options.annualUptakeIncreasePp,
    horizon_years: options.horizonYears,
    avoided_event_savings_per_active_user: options.avoidedEventSavingsPerActiveUser,
  }
  if (options.followupEngagementPct !== undefined) {
    body.followup_engagement_pct = options.followupEngagementPct
  }
  return request<BudgetImpactResponse>('/budget-impact', undefined, body)
}

export interface SurvivalOptions {
  nPerArm: number
  followupYears: number
  seed: number
}

export function postSurvival(
  inputs: Partial<ScenarioInputs>,
  options: SurvivalOptions,
): Promise<SurvivalResponse> {
  return request<SurvivalResponse>(
    '/survival',
    undefined,
    {
      ...inputs,
      n_per_arm: options.nPerArm,
      followup_years: options.followupYears,
      seed: options.seed,
    },
  )
}

/**
 * EVPI/EVPPI from PSA draws already held by the browser, so the expensive PSA
 * is never rerun for a value-of-information calculation.
 */
export function postValueOfInformation(
  results: PsaResponse['results'],
  wtp: number,
): Promise<VoiResponse> {
  return request<VoiResponse>('/value-of-information', { wtp }, { results })
}

/**
 * Illustrative DHT readiness assessment. The body is passed through unchanged:
 * the R layer owns the defaults, the ranges and the level sets, so an input it
 * rejects comes back as R's own message.
 */
export function postReadiness(inputs: ReadinessInputs): Promise<ReadinessResponse> {
  return request<ReadinessResponse>('/readiness', undefined, inputs)
}

/**
 * HTA decision summary and evidence priorities. The body carries what the other
 * endpoints already produced; the R layer derives every domain status, the
 * overall position and the priorities, so the client must not send statuses.
 * Omitting a completed-analysis value is how a caller says "not run yet"; R then
 * returns its own not-yet-available wording.
 */
export function postHtaSummary(
  inputs: HtaSummaryInputs,
  wtp: number,
): Promise<HtaSummaryResponse> {
  return request<HtaSummaryResponse>('/hta-summary', { wtp }, inputs)
}

export interface ValueBasedPriceOptions {
  /** Reference WTP threshold in EUR per QALY. */
  wtp: number
  /**
   * The annual intervention price the analysis runs at and compares the
   * supported price against; R falls back to the scenario's own price.
   */
  currentPrice?: number
}

/**
 * Value-based price: the highest annual intervention price the model supports at
 * the reference threshold, the headroom against the current price, the relative
 * risk reduction the current price would require and the 3 x 3 scan across the
 * model's own risk-reduction and year-1 engagement bounds. The body is passed
 * through unchanged and R derives every value, status, label and sentence, so
 * the client never computes a price, a threshold or a status.
 */
export function postValueBasedPrice(
  inputs: Partial<ScenarioInputs>,
  options: ValueBasedPriceOptions,
): Promise<ValueBasedPriceResponse> {
  const body: Record<string, unknown> = { ...inputs }
  if (options.currentPrice !== undefined) {
    body.current_price = options.currentPrice
  }
  return request<ValueBasedPriceResponse>('/value-based-price', { wtp: options.wtp }, body)
}

/**
 * The Guided Tutorial Part 1 contract: the tutorial's own defaults, its control
 * metadata (labels, units, ranges, steps and explanations) and the instructional
 * wording of all four steps. R owns every string, so the client renders the
 * tutorial's teaching copy rather than holding a copy of it.
 */
export function fetchTutorial(): Promise<TutorialResponse> {
  return request<TutorialResponse>('/tutorial')
}

/**
 * All four Guided Tutorial Part 1 results in one deterministic response. The
 * body carries only the tutorial's own nine controls; every other value is a
 * tutorial-owned default in R, so a tutorial request cannot read or move a
 * full-analysis setting. The response is presentation-ready: values, statuses,
 * interpretations, table rows and formatted strings all come from R.
 */
export function postTutorialPart1(
  inputs: TutorialInputs,
): Promise<TutorialPart1Response> {
  return request<TutorialPart1Response>('/tutorial/part1', undefined, inputs)
}

/**
 * The Guided Tutorial Part 2 contract: the five section names with only the
 * implemented ones marked available, R's instructional copy, the negotiated-price
 * control metadata and the chart's labels, series colours and legend entries.
 */
export function fetchTutorialPart2(): Promise<TutorialPart2ContractResponse> {
  return request<TutorialPart2ContractResponse>('/tutorial/part2')
}

export interface TutorialPart2CaseRequest {
  /** Omitted for a new case; the handle R issued to resume the same case. */
  case_id?: string
  /** Retry support: R never returns the excluded case. Not used yet. */
  exclude_case_id?: string
  /** Pins the draw, for a fixture. The interface never sends one. */
  seed?: number
}

/**
 * Creates a Part 2 case, or resumes the one the caller already holds. The
 * response carries the opaque `case_id` (the only part of the draw the client
 * stores or sends), the case's facts, the brief's introduction and the case's
 * complete 43-point price curve. This call costs about forty-four model runs, so
 * it belongs behind an explicit action with progress.
 */
export function postTutorialPart2Case(
  body: TutorialPart2CaseRequest,
): Promise<Part2CaseResponse> {
  return request<Part2CaseResponse>('/tutorial/part2/case', undefined, body)
}

export interface TutorialPart2EvaluateRequest {
  case_id: string
  price: number
  /** The budget-impact coverage cap; omitted takes R's tutorial default. */
  coverage?: number
  /**
   * The curve this case already returned. Posting it lets R re-classify the curve
   * instead of re-running its forty-three model runs, so a price change costs one
   * model run. R decides every classification in either path.
   */
  curve?: Part2Curve
  /**
   * The DHT readiness exercise's four answers, sent as R's level ids. R validates
   * each one, maps it onto the readiness input it represents and decides every
   * status; an omitted answer takes R's default for that question.
   */
  interoperability?: string
  governance?: string
  clinical_workflow?: string
  patient_engagement?: string
}

/**
 * The Part 2 result at one negotiated price and one coverage cap: R's
 * value-for-money state and detail, the highest acceptable price, the marker, the
 * full price curve with R's pass/fail classification, the budget-impact result
 * at the coverage cap (rows, chart series, total, affordability state and the
 * maximum affordable coverage R found), and the DHT readiness exercise's result
 * at the four submitted answers. Nothing here is derived in the client.
 */
export function postTutorialPart2Evaluate(
  body: TutorialPart2EvaluateRequest,
): Promise<Part2EvaluateResponse> {
  return request<Part2EvaluateResponse>('/tutorial/part2/evaluate', undefined, body)
}

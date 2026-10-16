/**
 * Application state for the eQalb frontend.
 *
 * A single shared store, because the analyses reuse one parameter set and some
 * results feed others: the PSA draws are posted back for value of information,
 * and every analysis reuses the same engagement and cost assumptions. Expensive
 * analyses only run when the user asks for them (the Shiny app behaves the same
 * way), so every panel has an explicit action and its own busy/error state.
 *
 * No model logic lives here. The store assembles request bodies, calls the API
 * and keeps what R returned. Result objects use `shallowRef` because they are
 * replaced wholesale and never edited field by field, which keeps a 2,000-draw
 * PSA from being wrapped in a deep reactive proxy.
 */

import { computed, reactive, ref, shallowRef } from 'vue'
import * as api from '../api/client'
import { ApiError } from '../api/client'
import type { BudgetImpactOptions, SurvivalOptions } from '../api/client'
import {
  OWSA_OUTCOME_LABELS,
  SCENARIO_PARAMETER_IDS,
  type BaseCaseResponse,
  type BudgetImpactResponse,
  type DefaultsResponse,
  type HealthResponse,
  type HtaSummaryInputs,
  type HtaSummaryResponse,
  type OwsaBound,
  type OwsaOutcome,
  type OwsaRangeOverride,
  type OwsaResponse,
  type ParameterSpec,
  type PsaResponse,
  type ReadinessInputs,
  type ReadinessResponse,
  type ScenarioInputs,
  type ScenarioParameterId,
  type SurvivalResponse,
  type ValueBasedPriceResponse,
  type VoiResponse,
} from '../api/types'
import { isNum } from '../format'
import { useAppBusy } from './useAppBusy'

/**
 * Converts a fraction (0.7, as the scenario inputs store engagement) to the
 * percentage (70) the readiness API expects. This is a unit conversion for
 * transport only: no readiness value is computed or interpreted here.
 */
function toPercent(fraction: number | undefined): number | undefined {
  return isNum(fraction) ? fraction * 100 : undefined
}

export type AnalysisKey =
  | 'baseCase'
  | 'psa'
  | 'owsa'
  | 'budget'
  | 'survival'
  | 'voi'
  | 'readiness'
  | 'htaSummary'
  | 'valueBasedPrice'

const ANALYSIS_KEYS: readonly AnalysisKey[] = [
  'baseCase',
  'psa',
  'owsa',
  'budget',
  'survival',
  'voi',
  'readiness',
  'htaSummary',
  'valueBasedPrice',
]

const SCENARIO_IDS = new Set<string>(SCENARIO_PARAMETER_IDS)

/**
 * The status sentence the app-wide loading indicator shows while an analysis
 * runs. Each panel's own button carries the same sentence in its pending state,
 * so the loader, the button and the panel's placeholder describe the one wait the
 * one way; the PSA is the only exception, because its wait names the run's own
 * size instead (see psaInFlight). Only the long operations ever reach the card; a
 * fast run finishes inside the indicator's grace period and shows nothing.
 */
const ANALYSIS_BUSY_LABELS: Record<AnalysisKey, string> = {
  baseCase: 'Running the base case…',
  psa: 'Running the probabilistic sensitivity analysis…',
  owsa: 'Running the sensitivity analysis…',
  budget: 'Running the budget impact…',
  survival: 'Simulating survival…',
  voi: 'Calculating the value of information…',
  readiness: 'Assessing readiness…',
  htaSummary: 'Assessing the HTA summary…',
  valueBasedPrice: 'Calculating the value-based price…',
}

const appBusy = useAppBusy()

function isScenarioParameterId(id: string): id is ScenarioParameterId {
  return SCENARIO_IDS.has(id)
}

function describeError(error: unknown): string {
  if (error instanceof ApiError) return error.message
  if (error instanceof Error) return error.message
  return 'Unexpected error.'
}

// --- Service and inputs ------------------------------------------------------

const health = ref<HealthResponse | null>(null)
const defaults = shallowRef<DefaultsResponse | null>(null)
const loading = ref(true)
const loadError = ref<string | null>(null)

const inputs = reactive<Partial<Record<ScenarioParameterId, number>>>({})
const wtp = ref(100000)

/**
 * Fallbacks until the contract arrives. They repeat what /api/defaults publishes
 * (simulation_defaults), which mirrors the Shiny PSA controls, so the form shows
 * Shiny's values from the first paint.
 */
const psaSims = ref(1000)
const psaSeed = ref(12345)
const owsaOutcome = ref<OwsaOutcome>('inmb')
/** The ranges the user has adjusted in this session; null means "R's own ranges". */
const owsaBounds = shallowRef<OwsaRangeOverride[] | null>(null)

/**
 * R's ranges for the scenario currently in the form: the response of
 * POST /api/owsa-defaults, which derives one range per parameter from that
 * scenario's own values without running the analysis. The range editor shows these
 * values, so it always reflects the assumptions in the form; `owsaBoundsNote` is
 * R's sentence about how they are derived.
 */
const owsaDefaultBounds = shallowRef<OwsaBound[] | null>(null)
const owsaBoundsNote = ref('')
const owsaDefaultsError = ref<string | null>(null)
/** True while R is deriving the ranges, for a caller that wants to show progress. */
const owsaDefaultsBusy = ref(false)

/**
 * Clinical target population: the full-analysis eligible population, shared by
 * the DHT readiness assessment and the budget-impact analysis (as in the Shiny
 * app, where it is a single Global Settings control). Its default comes from the
 * readiness contract in /api/defaults.
 */
const targetPopulation = ref(100000)

const budgetInputs = reactive({
  year1UptakePct: 10,
  annualUptakeIncreasePp: 5,
  horizonYears: 5,
  avoidedEventSavingsPerActiveUser: 0,
})

const survivalInputs = reactive({
  nPerArm: 1000,
  followupYears: 10,
  seed: 20261004,
})

/**
 * DHT readiness inputs other than the shared population and the shared
 * engagement values. Every one of these is initialised from the readiness block
 * of /api/defaults, so no default, range, level or unit is written down in
 * TypeScript. Engagement is deliberately absent: the tab reads the global
 * engagement inputs instead of holding a second copy of them.
 *
 * The field names are the request-body names, so the body is assembled without
 * a mapping table that could silently mistranslate a field.
 */
const readinessInputs = reactive({
  digital_access: 0,
  digital_suitability: 0,
  review_minutes: 0,
  supported_languages: 0,
  accessibility_features: false,
  interoperability: '',
  algorithm_governance: '',
})

// --- Results -----------------------------------------------------------------

const baseCase = shallowRef<BaseCaseResponse | null>(null)
const psa = shallowRef<PsaResponse | null>(null)
const owsa = shallowRef<OwsaResponse | null>(null)
const budget = shallowRef<BudgetImpactResponse | null>(null)
const survival = shallowRef<SurvivalResponse | null>(null)
const voi = shallowRef<VoiResponse | null>(null)
const readiness = shallowRef<ReadinessResponse | null>(null)
const htaSummary = shallowRef<HtaSummaryResponse | null>(null)
const valueBasedPrice = shallowRef<ValueBasedPriceResponse | null>(null)

/**
 * How many times each analysis has committed a new result in this session.
 *
 * It is the one signal the presentation layer needs to tell a *new* result from a
 * result it has already shown: the result objects themselves cannot say it,
 * because a second run can return exactly the same numbers, and a tab switch, a
 * theme change or an input edit must not read as a run. Only a successful run
 * bumps a revision — a failed or cancelled one reports its error and leaves the
 * counter alone — and it is bumped after the result has been assigned, so nothing
 * animates ahead of the value it belongs to.
 */
const resultRevisions = reactive<Record<AnalysisKey, number>>(
  Object.fromEntries(ANALYSIS_KEYS.map((key) => [key, 0])) as Record<AnalysisKey, number>,
)

/**
 * The request bodies that produced the stored results, serialised. Comparing
 * them with what the same request would be now is how a tab reports "computed
 * from earlier inputs", the same idea as the threshold-based staleness checks for
 * the base case and the PSA below. A result is never rewritten by an input
 * change: only its own action button replaces it.
 *
 * The one-way analysis is compared the same way, over its whole request: the
 * scenario, the threshold and the ranges it ran with. Its threshold-only check
 * could not see an assumption change, and every number in its table depends on
 * the scenario it ran on.
 */
const htaSummaryRun = shallowRef<string | null>(null)
const valueBasedPriceRun = shallowRef<string | null>(null)
const budgetRun = shallowRef<string | null>(null)
const survivalRun = shallowRef<string | null>(null)

/**
 * The two runs whose request body the client keeps as a value rather than as a
 * string: the one-way analysis and the readiness assessment — the two whose
 * responses do not echo their inputs — so a presentation of either run can list
 * the settings it actually used. Each holds the very object the request was built
 * from; the staleness check serialises it with the same function it compares
 * against, so the comparison and the display cannot disagree.
 */
const owsaRun = shallowRef<OwsaRunRequest | null>(null)
const readinessRun = shallowRef<ReadinessInputs | null>(null)

/**
 * What the stored value-of-information result was computed from: the PSA result
 * it reused, identified by reference because re-running the PSA replaces that
 * object, and the threshold it used. The draws themselves are the request body,
 * so a reference is the cheapest exact signature.
 */
const voiPsaSource = shallowRef<PsaResponse | null>(null)
const voiThreshold = shallowRef<number | null>(null)

const busy = reactive<Record<AnalysisKey, boolean>>(
  Object.fromEntries(ANALYSIS_KEYS.map((key) => [key, false])) as Record<AnalysisKey, boolean>,
)
const errors = reactive<Record<AnalysisKey, string | null>>(
  Object.fromEntries(ANALYSIS_KEYS.map((key) => [key, null])) as Record<AnalysisKey, string | null>,
)

/**
 * The iteration count of the PSA run that is in flight, or null when none is.
 *
 * It is captured when the run starts, so everything that describes the wait — the
 * button's pending label and the panel's in-flight line — describes the run that
 * is actually going, and editing the iterations field while it waits cannot
 * relabel it. Cleared when the run settles, either way.
 */
const psaInFlight = shallowRef<number | null>(null)

// --- Derived state -----------------------------------------------------------

/** Parameter groups in the order the R spec lists them. */
const parameterGroups = computed(() => {
  const groups = new Map<string, ParameterSpec[]>()
  for (const spec of defaults.value?.parameters ?? []) {
    const list = groups.get(spec.group)
    if (list) list.push(spec)
    else groups.set(spec.group, [spec])
  }
  return [...groups.entries()].map(([group, parameters]) => ({ group, parameters }))
})

/** How many inputs differ from the R base case, for the "changed" badge. */
const changedParameters = computed(() => {
  const specs: ParameterSpec[] = defaults.value?.parameters ?? []
  return specs.filter((spec) => {
    if (!isScenarioParameterId(spec.id)) return false
    const current = inputs[spec.id]
    return isNum(current) && Math.abs(current - spec.default) > 1e-12
  })
})

/**
 * True when anything the "Reset model inputs" control owns differs from the R
 * base case. It is the button's enabled condition, so the control is usable
 * exactly when it would do something. A zero R default (none of the 16 is zero,
 * but a future one could be) is compared by value rather than by truthiness.
 */
const modelInputsChanged = computed(() => {
  const loaded = defaults.value
  if (!loaded) return false
  if (Math.abs(wtp.value - loaded.simulation_defaults.reference_wtp) > 1e-9) return true
  return loaded.parameters.some((spec) => {
    if (!isScenarioParameterId(spec.id)) return false
    const current = inputs[spec.id]
    return !isNum(current) || Math.abs(current - spec.default) > 1e-12
  })
})

/** True when a result was produced at a different threshold than the current one. */
function isStale(resultWtp: number | null | undefined): boolean {
  if (resultWtp === null || resultWtp === undefined) return false
  return Math.abs(resultWtp - wtp.value) > 1e-9
}

const psaStale = computed(() => isStale(psa.value?.wtp))
const baseCaseStale = computed(() => isStale(baseCase.value?.wtp))
/**
 * True when the stored one-way result was produced from a different scenario, a
 * different threshold or different ranges than the ones now in force. The ranked
 * outcome is deliberately left out: the selector has its own notice, because
 * changing it selects a different ranking rather than making this result describe
 * assumptions that have moved.
 */
const owsaStale = computed(() =>
  owsa.value === null
    ? false
    : isBodyStale(
        owsaRun.value === null ? null : JSON.stringify(owsaRun.value),
        JSON.stringify(owsaRequest()),
      ),
)

/**
 * The PSA control bounds /api/defaults publishes, with the values the fallbacks
 * above use when the contract has not arrived yet. They mirror the Shiny controls
 * (100–10,000 in steps of 100, seed at least 1), so the form and the endpoint
 * cannot disagree about what is allowed.
 */
const psaBounds = computed(() => {
  const simulation = defaults.value?.simulation_defaults
  return {
    min: simulation?.psa_n_sim_min ?? 100,
    max: simulation?.psa_n_sim_max ?? 10000,
    step: simulation?.psa_n_sim_step ?? 100,
    seedMin: simulation?.psa_seed_min ?? 1,
  }
})

/** True when a stored result was produced from different inputs than the ones now in force. */
function isBodyStale(snapshot: string | null, current: string): boolean {
  return snapshot !== null && snapshot !== current
}

const readinessStale = computed(() =>
  readiness.value === null
    ? false
    : isBodyStale(
        readinessRun.value === null ? null : JSON.stringify(readinessRun.value),
        JSON.stringify(readinessBody()),
      ),
)

const htaSummaryStale = computed(() =>
  htaSummary.value === null
    ? false
    : isBodyStale(
        htaSummaryRun.value,
        JSON.stringify({ body: htaSummaryBody(), threshold: htaSummaryThreshold() }),
      ),
)

/**
 * True when the stored value-based price was computed from different assumptions
 * or a different threshold than the ones now in force. Like the readiness and HTA
 * summary tabs, this compares the request a run would send with the request that
 * produced the stored result, so it covers the 16 scenario inputs and the
 * reference threshold together and needs no separate field-by-field check.
 */
const valueBasedPriceStale = computed(() =>
  valueBasedPrice.value === null
    ? false
    : isBodyStale(
        valueBasedPriceRun.value,
        JSON.stringify(valueBasedPriceRequest()),
      ),
)

/** The same request comparison for the budget impact and the survival tab. */
const budgetStale = computed(() =>
  budget.value === null ? false : isBodyStale(budgetRun.value, JSON.stringify(budgetRequest())),
)

const survivalStale = computed(() =>
  survival.value === null
    ? false
    : isBodyStale(survivalRun.value, JSON.stringify(survivalRequest())),
)

/**
 * The value-of-information result is computed from the PSA's own draws and the
 * threshold, so it is stale once the PSA has been re-run or the threshold has
 * moved. A threshold change is the case the PSA staleness check does not cover
 * for this tab, and a re-run with the same number of successful draws leaves the
 * result in place, which is why the source is compared rather than the count.
 */
const voiStale = computed(() =>
  voi.value === null
    ? false
    : voiPsaSource.value !== psa.value || voiThreshold.value !== wtp.value,
)

/** How many analyses are currently stored, for the "clear results" control. */
const resultCount = computed(
  () =>
    [
      baseCase.value,
      psa.value,
      owsa.value,
      budget.value,
      survival.value,
      voi.value,
      readiness.value,
      htaSummary.value,
      valueBasedPrice.value,
    ].filter((result) => result !== null).length,
)

/**
 * How many analyses exist, so the "x of y analyses stored" counter is derived
 * from the same list the store tracks instead of a number written into a
 * template that a new analysis would leave stale.
 */
const analysisCount = ANALYSIS_KEYS.length

const referenceWtp = computed(() => defaults.value?.simulation_defaults.reference_wtp ?? 100000)
const modelMeta = computed(() => defaults.value?.model ?? null)

/**
 * The shared engagement values as the percentages the readiness API expects.
 */
const readinessEngagementPct = computed(() => ({
  year1: toPercent(inputs.engagement_year1),
  followup: toPercent(inputs.engagement_followup),
}))

/** Probability of cost-effectiveness at the threshold the PSA was run with. */
const probabilityCostEffective = computed<number | null>(() => {
  const result = psa.value
  if (!result) return null
  const thresholds = result.wtp_thresholds ?? []
  const values = Object.values(result.probability_cost_effective ?? {})
  const index = thresholds.findIndex((value) => Math.abs(value - result.wtp) < 1e-9)
  if (index >= 0 && index < values.length) return values[index]
  return null
})

const owsaOutcomeLabel = computed(() => OWSA_OUTCOME_LABELS[owsaOutcome.value])

// --- Actions -----------------------------------------------------------------

/**
 * Reads one numeric readiness default out of the contract. A missing entry means
 * the contract changed, so it is reported rather than silently replaced by a
 * default written down here.
 */
function readinessNumber(loaded: DefaultsResponse, id: string): number {
  const spec = loaded.readiness.parameters.find((entry) => entry.id === id)
  if (!spec) {
    console.warn(`Readiness parameter "${id}" is missing from /api/defaults.`)
    return 0
  }
  return spec.default
}

function readinessFlag(loaded: DefaultsResponse, id: string): boolean {
  const spec = loaded.readiness.parameters.find((entry) => entry.id === id)
  if (!spec) {
    console.warn(`Readiness parameter "${id}" is missing from /api/defaults.`)
    return false
  }
  return spec.default !== 0
}

function applyDefaults(loaded: DefaultsResponse): void {
  for (const spec of loaded.parameters) {
    if (isScenarioParameterId(spec.id)) {
      inputs[spec.id] = spec.default
    } else {
      // A parameter exists in R that this build does not know about. Ignoring it
      // keeps the form usable; the warning makes the drift visible.
      console.warn(`Unknown model parameter "${spec.id}" reported by /api/defaults.`)
    }
  }
  wtp.value = loaded.simulation_defaults.reference_wtp
  psaSims.value = loaded.simulation_defaults.psa_n_sim
  psaSeed.value = loaded.simulation_defaults.psa_seed
  survivalInputs.nPerArm = loaded.simulation_defaults.km_n_per_arm
  survivalInputs.followupYears = loaded.simulation_defaults.km_followup_years
  survivalInputs.seed = loaded.simulation_defaults.km_seed

  // Readiness defaults, ranges and choices come from the readiness contract. The
  // population is the shared full-analysis value and the two engagement rows are
  // the shared Global Settings engagement, so neither is copied into the tab.
  targetPopulation.value = readinessNumber(loaded, 'target_population')
  resetReadinessInputs()
}

/**
 * Restores the seven readiness-specific inputs to the defaults the contract
 * publishes and clears the stored readiness assessment, which is what Shiny's
 * "Reset values" button does (app.R, observeEvent(input$reset_readiness)). The
 * shared population and the shared engagement values are not touched here: the
 * tab shows them read-only precisely because they belong to the global
 * assumptions.
 */
function resetReadinessInputs(): void {
  const loaded = defaults.value
  if (!loaded) return
  readinessInputs.digital_access = readinessNumber(loaded, 'digital_access')
  readinessInputs.digital_suitability = readinessNumber(loaded, 'digital_suitability')
  readinessInputs.review_minutes = readinessNumber(loaded, 'review_minutes')
  readinessInputs.supported_languages = readinessNumber(loaded, 'supported_languages')
  readinessInputs.accessibility_features = readinessFlag(loaded, 'accessibility_features')
  readinessInputs.interoperability = loaded.readiness.choices.interoperability.default
  readinessInputs.algorithm_governance = loaded.readiness.choices.algorithm_governance.default
  readiness.value = null
  readinessRun.value = null
  errors.readiness = null
}

/**
 * Restores the 16 model assumptions and the reference WTP threshold to the R
 * base case. Nothing else is touched: PSA/Kaplan-Meier settings, the budget
 * assumptions, the readiness inputs, the shared target population and the edited
 * OWSA ranges are analysis settings of their own, and every completed result
 * stays in the store (a result that no longer matches the current inputs is
 * reported as such by the tab that shows it).
 */
function resetModelInputs(): void {
  const loaded = defaults.value
  if (!loaded) return
  for (const spec of loaded.parameters) {
    if (isScenarioParameterId(spec.id)) inputs[spec.id] = spec.default
  }
  wtp.value = loaded.simulation_defaults.reference_wtp
}

/** Drops every stored result. Inputs, analysis settings and errors are untouched. */
function clearResults(): void {
  baseCase.value = null
  psa.value = null
  owsa.value = null
  budget.value = null
  survival.value = null
  voi.value = null
  readiness.value = null
  htaSummary.value = null
  valueBasedPrice.value = null
  readinessRun.value = null
  htaSummaryRun.value = null
  valueBasedPriceRun.value = null
  budgetRun.value = null
  survivalRun.value = null
  owsaRun.value = null
  voiPsaSource.value = null
  voiThreshold.value = null
  for (const key of ANALYSIS_KEYS) errors[key] = null
}

/** Loads the parameter contract and the base case from the R model. */
async function loadService(): Promise<void> {
  loading.value = true
  loadError.value = null
  // The token settles exactly once, in this function's own `finally`, so a
  // failed load cannot leave the busy state behind.
  const done = appBusy.start('Loading the model service…')
  try {
    const [healthResponse, defaultsResponse] = await Promise.all([
      api.fetchHealth(),
      api.fetchDefaults(),
    ])
    health.value = healthResponse
    defaults.value = defaultsResponse
    applyDefaults(defaultsResponse)
  } catch (error) {
    loadError.value = describeError(error)
  } finally {
    loading.value = false
    done()
  }
}

async function refreshHealth(): Promise<void> {
  try {
    health.value = await api.fetchHealth()
  } catch (error) {
    health.value = null
    loadError.value = describeError(error)
  }
}

/** The scenario body sent with every analysis: the full, explicit parameter set. */
function scenarioBody(): Partial<ScenarioInputs> {
  const body: Partial<ScenarioInputs> = {}
  for (const id of SCENARIO_PARAMETER_IDS) {
    const value = inputs[id]
    if (isNum(value)) {
      body[id] = id === 'cycles' ? Math.round(value) : value
    }
  }
  return body
}

/**
 * The scenario body, serialised, for anything that has to react to the assumptions
 * rather than to each input: the one-way range editor asks R for the ranges in force
 * whenever this changes. It is the request body itself, so nothing is derived here.
 */
const scenarioSignature = computed(() => JSON.stringify(scenarioBody()))

/**
 * Writes one model input. The id is checked against the known parameter list, so
 * a value reported by R that this build does not understand can never reach the
 * request body.
 */
function setInput(id: string, value: number): void {
  if (!isScenarioParameterId(id) || !isNum(value)) return
  inputs[id] = id === 'cycles' ? Math.round(value) : value
}

async function run(key: AnalysisKey, action: () => Promise<void>): Promise<void> {
  // One request per analysis at a time. Each panel disables its own action while
  // it waits, so this is the belt to that braces: a second call — a double click
  // that lands before the disabled state paints, a second keyboard activation, a
  // confirmation dialog confirmed twice — finds the analysis already running and
  // leaves the first request alone. Nothing about the analysis is reset by the
  // refusing call, and its caller still gets a promise that resolves.
  if (busy[key]) return
  busy[key] = true
  errors[key] = null
  // The token is this run's own completion; it is called in the `finally` below,
  // so a rejected analysis clears the busy state with the error message it shows.
  const done = appBusy.start(ANALYSIS_BUSY_LABELS[key])
  try {
    await action()
    // The action resolved, so its result is the new stored one: this is the only
    // place a revision moves, and it moves after the assignment inside `action`.
    resultRevisions[key] += 1
  } catch (error) {
    errors[key] = describeError(error)
  } finally {
    busy[key] = false
    done()
  }
}

function runBaseCase(): Promise<void> {
  return run('baseCase', async () => {
    baseCase.value = await api.postBaseCase(scenarioBody(), wtp.value)
  })
}

function runPsa(): Promise<void> {
  // The iterations and the seed are read once, here, before the request is built:
  // they are what this run is, so the request, the pending label and the in-flight
  // line all describe the same run even if the fields are edited while it waits.
  const sims = psaSims.value
  const seed = psaSeed.value
  return run('psa', async () => {
    psaInFlight.value = sims
    try {
      const result = await api.postPsa(scenarioBody(), {
        nSim: sims,
        seed,
        wtp: wtp.value,
      })
      psa.value = result
      // New draws invalidate a value-of-information result computed from old ones.
      if (voi.value && voi.value.n !== result.n_successful) voi.value = null
    } finally {
      psaInFlight.value = null
    }
  })
}

/**
 * What a one-way run would send, apart from the ranked outcome, which has its own
 * notice. The ranges are the user's own absolute values when this session has any,
 * and otherwise absent: omitting them is how the request asks R for the ranges it
 * derives from the scenario. No range is derived, clamped or defaulted here.
 */
function owsaRequest(): OwsaRunRequest {
  return { wtp: wtp.value, body: scenarioBody(), bounds: owsaBounds.value }
}

function runOwsa(outcome: OwsaOutcome = owsaOutcome.value): Promise<void> {
  owsaOutcome.value = outcome
  const request = owsaRequest()
  return run('owsa', async () => {
    owsa.value = await api.postOwsa(scenarioBody(), {
      outcome,
      wtp: wtp.value,
      bounds: owsaBounds.value ?? undefined,
    })
    owsaRun.value = request
  })
}

/**
 * Asks R for the ranges that are in force for the assumptions currently in the
 * form, so the range editor can show them. It runs no model scenario, and it sends
 * this session's adjusted ranges with it so R can label each row itself. A slow
 * answer that a newer request has already replaced is discarded, so the editor can
 * never show ranges from an older scenario.
 */
let owsaDefaultsToken = 0

async function refreshOwsaDefaults(): Promise<void> {
  const token = ++owsaDefaultsToken
  owsaDefaultsBusy.value = true
  try {
    const response = await api.postOwsaDefaults(scenarioBody(), owsaBounds.value ?? undefined)
    if (token !== owsaDefaultsToken) return
    owsaDefaultBounds.value = response.bounds
    owsaBoundsNote.value = response.bounds_note
    owsaDefaultsError.value = null
  } catch (error) {
    if (token !== owsaDefaultsToken) return
    // The last answer R gave is kept, and the editor says so rather than showing
    // ranges as if they were current.
    owsaDefaultsError.value = describeError(error)
  } finally {
    if (token === owsaDefaultsToken) owsaDefaultsBusy.value = false
  }
}

/**
 * The budget-impact request: the scenario, the shared target population and the
 * budget-specific settings. Named separately from runBudget() so the staleness
 * check compares exactly what a run would send.
 */
function budgetRequest(): { body: Partial<ScenarioInputs>; options: BudgetImpactOptions } {
  return {
    body: scenarioBody(),
    options: {
      population: targetPopulation.value,
      year1UptakePct: budgetInputs.year1UptakePct,
      annualUptakeIncreasePp: budgetInputs.annualUptakeIncreasePp,
      horizonYears: budgetInputs.horizonYears,
      avoidedEventSavingsPerActiveUser: budgetInputs.avoidedEventSavingsPerActiveUser,
    },
  }
}

function runBudget(): Promise<void> {
  return run('budget', async () => {
    const request = budgetRequest()
    budget.value = await api.postBudgetImpact(request.body, request.options)
    budgetRun.value = JSON.stringify(request)
  })
}

/**
 * The DHT readiness request body. Engagement is taken from the shared Global
 * Settings inputs (converted from fractions to the percentages R expects) and the
 * population from the shared Clinical target population, so the assessment and
 * the other analyses cannot disagree about them.
 *
 * It is a named function as well as the request body because the tab compares it
 * with the body the stored assessment was produced from, to report staleness.
 */
function readinessBody(): ReadinessInputs {
  return {
    target_population: targetPopulation.value,
    ...readinessInputs,
    readiness_year1_engagement: readinessEngagementPct.value.year1,
    readiness_followup_engagement: readinessEngagementPct.value.followup,
  }
}

function runReadiness(): Promise<void> {
  return run('readiness', async () => {
    const body = readinessBody()
    readiness.value = await api.postReadiness(body)
    readinessRun.value = body
  })
}

/**
 * The HTA decision-summary body. It carries only what this session has already
 * computed: an analysis that has not been run is simply absent, and R then
 * reports its own "Not available" / "Not yet assessable" wording rather than a
 * value this client made up. Every number is a field copied out of another
 * response — the base-case ICER, the PSA's probability and mean NMB, the value of
 * information's EVPI and EVPPI rows, the budget-impact totals — and the six
 * scenario signals are the current global assumptions. The readiness block
 * follows the same rule: it is sent only once the readiness assessment has been
 * run, as in the Shiny app, and R derives the domains from those inputs.
 */
function htaSummaryBody(): HtaSummaryInputs {
  const body: HtaSummaryInputs = { ...scenarioBody() }

  const base = baseCase.value
  if (base && isNum(base.icer)) body.icer = base.icer

  const psaResult = psa.value
  if (psaResult) {
    const probability = probabilityCostEffective.value
    if (isNum(probability)) body.probability_cost_effective = probability
    if (isNum(psaResult.mean_net_monetary_benefit)) {
      body.mean_incremental_nmb = psaResult.mean_net_monetary_benefit
    }
  }

  const voiResult = voi.value
  if (voiResult) {
    if (isNum(voiResult.evpi.evpi)) body.evpi = voiResult.evpi.evpi
    if (voiResult.evppi.available) {
      // The rows R would read back; an unavailable EVPPI table is simply omitted.
      const rows = voiResult.evppi.table
        .filter((row) => isNum(row.evppi))
        .map((row) => ({ parameter: row.parameter, evppi: row.evppi as number }))
      if (rows.length > 0) {
        body.evppi_table = rows
        body.highest_evppi = rows[0].evppi
      }
    }
  }

  const bia = budget.value
  if (bia) {
    if (isNum(bia.cumulative_net_budget_impact)) {
      body.cumulative_budget_impact = bia.cumulative_net_budget_impact
    }
    if (isNum(bia.total_intervention_cost)) {
      body.bia_intervention_cost = bia.total_intervention_cost
    }
    if (isNum(bia.total_implementation_cost)) {
      body.bia_implementation_cost = bia.total_implementation_cost
    }
    if (isNum(bia.total_healthcare_savings)) {
      body.bia_healthcare_savings = bia.total_healthcare_savings
    }
  }

  if (readiness.value) {
    body.readiness = {
      target_population: targetPopulation.value,
      ...readinessInputs,
      readiness_year1_engagement: readinessEngagementPct.value.year1,
      readiness_followup_engagement: readinessEngagementPct.value.followup,
    }
  }

  return body
}

/**
 * The threshold the summary is assessed at: the one the PSA (and therefore the
 * value of information) was run with, so the probability, the reference threshold
 * and the priorities all describe the same assessment; without a PSA it falls
 * back to the current threshold. Named separately from runHtaSummary() so the
 * staleness check compares exactly what a run would send.
 */
function htaSummaryThreshold(): number {
  const psaThreshold = psa.value?.wtp
  return isNum(psaThreshold) ? psaThreshold : wtp.value
}

function runHtaSummary(): Promise<void> {
  return run('htaSummary', async () => {
    const body = htaSummaryBody()
    const threshold = htaSummaryThreshold()
    htaSummary.value = await api.postHtaSummary(body, threshold)
    htaSummaryRun.value = JSON.stringify({ body, threshold })
  })
}

/**
 * The value-based price request: the current scenario and the reference threshold.
 * The current annual price is the scenario's own intervention_price, so the model
 * run, the price solve and the headroom the response reports all describe one
 * price and the client sends no separate price field. Named separately from
 * runValueBasedPrice() so the staleness check compares exactly what a run sends.
 */
function valueBasedPriceRequest(): { body: Partial<ScenarioInputs>; threshold: number } {
  return { body: scenarioBody(), threshold: wtp.value }
}

/**
 * Runs calculate_value_based_price() in R. It is deterministic but costs about 40
 * model runs, so it only ever happens on an explicit action, exactly like the PSA
 * and the one-way analysis. A previous result is not cleared by this call: it is
 * replaced only when R answers, and an error leaves it in place with the message
 * beside it.
 */
function runValueBasedPrice(): Promise<void> {
  return run('valueBasedPrice', async () => {
    const request = valueBasedPriceRequest()
    valueBasedPrice.value = await api.postValueBasedPrice(request.body, {
      wtp: request.threshold,
    })
    valueBasedPriceRun.value = JSON.stringify(request)
  })
}

/**
 * The survival request: the scenario plus the tab's sample size, follow-up and
 * seed. Named separately from runSurvival() so the staleness check compares
 * exactly what a run would send.
 */
function survivalRequest(): { body: Partial<ScenarioInputs>; options: SurvivalOptions } {
  return {
    body: scenarioBody(),
    options: {
      nPerArm: survivalInputs.nPerArm,
      followupYears: survivalInputs.followupYears,
      seed: survivalInputs.seed,
    },
  }
}

function runSurvival(): Promise<void> {
  return run('survival', async () => {
    const request = survivalRequest()
    survival.value = await api.postSurvival(request.body, request.options)
    survivalRun.value = JSON.stringify(request)
  })
}

function runVoi(): Promise<void> {
  return run('voi', async () => {
    const source = psa.value
    if (!source) {
      throw new Error(
        'Run a PSA first: the value-of-information calculation reuses its simulation draws.',
      )
    }
    // The threshold and the draw source are captured before the call, so a PSA
    // re-run while this one is in flight is still reported as a stale result.
    const threshold = wtp.value
    voi.value = await api.postValueOfInformation(source.results, threshold)
    voiPsaSource.value = source
    voiThreshold.value = threshold
  })
}

/** Convenience for the deterministic analyses, which are cheap enough to batch. */
function runDeterministic(): Promise<void> {
  return Promise.all([runBaseCase(), runBudget(), runSurvival()]).then(() => undefined)
}

function setOwsaBounds(bounds: OwsaRangeOverride[] | null): void {
  owsaBounds.value = bounds
}

/**
 * The shared store. It is returned as a reactive object so components read
 * `model.wtp` rather than `model.wtp.value`: that keeps templates readable and
 * avoids the ref-unwrapping mistakes a plain object invites.
 */
const model = reactive({
  // service
  health,
  defaults,
  loading,
  loadError,
  loadService,
  refreshHealth,
  // inputs
  inputs,
  wtp,
  psaSims,
  psaSeed,
  psaBounds,
  owsaOutcome,
  owsaBounds,
  owsaDefaultBounds,
  owsaBoundsNote,
  owsaDefaultsError,
  owsaDefaultsBusy,
  refreshOwsaDefaults,
  scenarioSignature,
  targetPopulation,
  budgetInputs,
  survivalInputs,
  readinessInputs,
  parameterGroups,
  changedParameters,
  modelInputsChanged,
  referenceWtp,
  modelMeta,
  readinessEngagementPct,
  resetModelInputs,
  resetReadinessInputs,
  clearResults,
  resultCount,
  analysisCount,
  setInput,
  setOwsaBounds,
  // results
  baseCase,
  psa,
  owsa,
  budget,
  survival,
  voi,
  readiness,
  htaSummary,
  valueBasedPrice,
  resultRevisions,
  voiPsaSource,
  voiThreshold,
  owsaRun,
  readinessRun,
  probabilityCostEffective,
  owsaOutcomeLabel,
  psaStale,
  baseCaseStale,
  owsaStale,
  budgetStale,
  survivalStale,
  voiStale,
  readinessStale,
  htaSummaryStale,
  valueBasedPriceStale,
  // run state
  busy,
  errors,
  psaInFlight,
  runBaseCase,
  runPsa,
  runOwsa,
  runBudget,
  runSurvival,
  runVoi,
  runReadiness,
  runHtaSummary,
  runValueBasedPrice,
  runDeterministic,
})

export function useModel() {
  return model
}

/**
 * The request one one-way sensitivity-analysis run was sent, kept beside its
 * result. Exported so a presentation of that run can list the settings it used
 * without reading the panel's controls.
 */
export interface OwsaRunRequest {
  wtp: number
  body: Partial<ScenarioInputs>
  bounds: OwsaRangeOverride[] | null
}

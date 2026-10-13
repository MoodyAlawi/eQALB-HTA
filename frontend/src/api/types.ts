/**
 * Response contracts for the eQalb model API (api/main.py -> api/plumber.R).
 *
 * These mirror the JSON the R model returns verbatim. Two properties of that
 * JSON matter throughout:
 *
 *  1. A number can be `null`. The R layer turns non-finite values (an ICER of
 *     Inf, a median that is never reached) into JSON null rather than
 *     "Infinity"/"NaN", so the UI must distinguish "not interpretable" from a
 *     real value instead of printing it.
 *  2. Every response carries `notice`, the simulated-data disclaimer.
 *
 * Types are transcribed from live responses rather than inferred from the R
 * source, so a contract change surfaces here as a type error instead of as a
 * blank chart.
 */

/** Numbers arrive as `number | null` wherever R could not compute a value. */
export type Num = number | null

export interface Notice {
  notice: string
}

// --- Service metadata --------------------------------------------------------

export interface HealthResponse extends Notice {
  status: 'ok' | 'degraded'
  service: string
  error?: string
  root?: string
  model_modules?: string[]
  model_ready?: boolean
  model_functions?: Record<string, boolean>
  r_model?: {
    configured_workers: number
    ready_workers: number
    rscript?: string
    endpoints?: string[]
    startup_error?: string | null
  }
  r_model_error?: string | null
}

export interface ParameterSpec {
  id: string
  label: string
  group: string
  unit: string
  /** The R base-case value, which the form shows as its default. */
  default: number
  min: number
  max: number
  step: number
  /** True when the model stores a fraction but the form shows a percentage. */
  percent: boolean
  /**
   * The explanation from CC_INFO_TEXT (eqalb_ui_copy.R), verbatim, or "" when
   * this input has none. The text is R's, not the client's.
   */
  info: string
}

/**
 * One row of R's one-way range policy for a scenario (see the OwsaBound interface
 * further down): the value the parameter has in that scenario, the range R derives
 * for it, the domain an override has to stay inside, R's own wording for the range,
 * and R's verdict on whether the active values are its model default or an adjusted
 * range. The client renders these fields and never classifies, clamps or derives a
 * range itself.
 */

/**
 * One full-analysis DHT readiness input. `type` decides the control: "number"
 * for the numeric inputs (with `min`/`max`/`step`, where a null bound means
 * "no bound") and "boolean" for the accessibility checkbox, whose `default` is
 * 1 or 0.
 */
export interface ReadinessParameterSpec {
  id: string
  label: string
  group: string
  unit: string
  type: 'number' | 'boolean'
  default: number
  min: number | null
  max: number | null
  step: number
  percent: boolean
  /** The explanation from CC_INFO_TEXT, verbatim, or "" when there is none. */
  info: string
}

/** A select-style readiness input: its levels and the value Shiny preselects. */
export interface ReadinessChoiceSet {
  label: string
  default: string
  levels: string[]
  /**
   * The explanation from CC_INFO_TEXT, verbatim, or "" when there is none.
   * `interoperability` carries R's own definition
   * (`tutorial_interop_definition`); `algorithm_governance` carries "" because no
   * such wording exists in R and none is invented on the client.
   */
  info: string
}

export interface ReadinessDefaults {
  parameters: ReadinessParameterSpec[]
  choices: {
    interoperability: ReadinessChoiceSet
    algorithm_governance: ReadinessChoiceSet
  }
}

export interface SimulationDefaults {
  /** PSA simulation count and its permitted range, as the Shiny controls define them. */
  psa_n_sim: number
  psa_seed: number
  psa_n_sim_min: number
  psa_n_sim_max: number
  psa_n_sim_step: number
  psa_seed_min: number
  reference_wtp: number
  km_n_per_arm: number
  km_followup_years: number
  km_seed: number
}

export interface ModelMeta {
  cycles: number
  states: string[]
  strategies: string[]
  perspective: string
}

export interface DefaultsResponse extends Notice {
  parameters: ParameterSpec[]
  owsa_parameters: OwsaBound[]
  /**
   * R's sentence about how the one-way ranges are derived
   * (EQALB_OWSA_RANGE_NOTE in eqalb_owsa.R), shown with the range editor.
   */
  owsa_bounds_note: string
  rrr_sensitivity_range: { low: number; high: number }
  simulation_defaults: SimulationDefaults
  readiness: ReadinessDefaults
  /**
   * The analysis explanations from CC_INFO_TEXT, keyed exactly as the Shiny
   * dictionary keys them (see COLUMN_INFO_KEYS in api/plumber.R). Only the keys
   * the browser interface uses are published; `tutorial_interop_definition` is
   * the one tutorial entry that is, because it is the only interoperability
   * definition R has and the readiness tab shows it on that control.
   */
  info_text: Record<string, string>
  /**
   * The paragraph Shiny shows above the sensitivity-analysis summary
   * (OWSA_SUMMARY_NOTE in eqalb_ui_copy.R); POST /api/owsa returns the same
   * string as `summary_note`.
   */
  owsa_summary_note: string
  /**
   * The sentence Shiny's sensitivity-analysis summary shows until the analysis has
   * been run (OWSA_PRERUN_NOTE in eqalb_ui_copy.R). The narrative for a completed
   * run arrives with POST /api/owsa.
   */
  owsa_prerun_note: string
  model: ModelMeta
}

// --- Scenario inputs ---------------------------------------------------------

/**
 * The 16 model inputs accepted by every analysis endpoint. Any id in
 * /api/defaults that is missing here is ignored by the form (and logged), so
 * contract drift stays visible without being fatal.
 */
export interface ScenarioInputs {
  intervention_price: number
  implementation_cost: number
  healthcare_savings: number
  rrr: number
  engagement_year1: number
  engagement_followup: number
  utility_no_event: number
  utility_post_mi: number
  utility_post_stroke: number
  cost_post_mi_year1: number
  cost_post_mi_followup: number
  cost_post_stroke_year1: number
  cost_post_stroke_followup: number
  discount_rate_cost: number
  discount_rate_effect: number
  cycles: number
}

export type ScenarioParameterId = keyof ScenarioInputs

export const SCENARIO_PARAMETER_IDS: readonly ScenarioParameterId[] = [
  'intervention_price',
  'implementation_cost',
  'healthcare_savings',
  'rrr',
  'engagement_year1',
  'engagement_followup',
  'utility_no_event',
  'utility_post_mi',
  'utility_post_stroke',
  'cost_post_mi_year1',
  'cost_post_mi_followup',
  'cost_post_stroke_year1',
  'cost_post_stroke_followup',
  'discount_rate_cost',
  'discount_rate_effect',
  'cycles',
]

// --- Base case ---------------------------------------------------------------

export interface CostComponents {
  intervention: Num
  implementation: Num
  savings: Num
  no_event: Num
  post_mi: Num
  post_stroke: Num
  /** intervention + implementation + no_event + post_mi + post_stroke - savings */
  total: Num
}

export interface QalyComponents {
  no_event: Num
  post_mi: Num
  post_stroke: Num
  /** no_event + post_mi + post_stroke */
  total: Num
}

export interface BaseCaseResponse extends Notice {
  incremental_cost: Num
  incremental_qalys: Num
  icer: Num
  net_monetary_benefit: Num
  wtp: number
  cost_effective: boolean | null
  cost_components: CostComponents
  qaly_components: QalyComponents
  /** The scenario the model actually ran, using the R argument names. */
  inputs: Record<string, Num>
}

// --- PSA ---------------------------------------------------------------------

export interface PsaCloudPoint {
  simulation: number
  incremental_cost: Num
  incremental_qalys: Num
  icer: Num
}

/** One PSA draw, including the sampled value of every uncertain parameter. */
export interface PsaDraw extends PsaCloudPoint {
  cost_intervention: Num
  cost_implementation: Num
  cost_savings: Num
  cost_no_event: Num
  cost_post_mi: Num
  cost_post_stroke: Num
  qaly_no_event: Num
  qaly_post_mi: Num
  qaly_post_stroke: Num
  scenario_rrr: Num
  scenario_engagement_year1: Num
  scenario_engagement_followup: Num
  scenario_utility_no_event: Num
  scenario_utility_post_mi: Num
  scenario_utility_post_stroke: Num
  scenario_intervention_price: Num
  scenario_implementation_cost: Num
  scenario_healthcare_savings: Num
}

export interface CeacPoint {
  wtp: number
  probability: Num
}

export interface PsaResponse extends Notice {
  n_requested: number
  n_successful: number
  n_failed: number
  seed: number
  wtp: number
  max_wtp: number
  mean_incremental_cost: Num
  mean_incremental_qalys: Num
  mean_net_monetary_benefit: Num
  median_icer: Num
  /** Mean of each value variable, keyed by its heemod component name. */
  mean_components: Record<string, Num>
  /** Keyed by the threshold formatted as "50,000". */
  probability_cost_effective: Record<string, Num>
  wtp_thresholds: number[]
  ceac: CeacPoint[]
  cloud: PsaCloudPoint[]
  /** The full draws; post these back to /api/value-of-information. */
  results: PsaDraw[]
}

// --- One-way sensitivity analysis -------------------------------------------

export interface OwsaRow {
  parameter: string
  parameter_id: string
  base_value: Num
  low_value: Num
  high_value: Num
  low_incremental_cost: Num
  high_incremental_cost: Num
  low_incremental_qalys: Num
  high_incremental_qalys: Num
  low_icer: Num
  high_icer: Num
  low_inmb: Num
  high_inmb: Num
  /** The chosen ranking outcome at the low and at the high bound. */
  selected_outcome_low: Num
  selected_outcome_high: Num
  impact_range: Num
  low_cost_effective: boolean | null
  high_cost_effective: boolean | null
  low_warning: string
  high_warning: string
}

/**
 * One row of R's one-way range policy for a scenario, in the shape both
 * `POST /api/owsa` and `POST /api/owsa-defaults` return it and the shape
 * `GET /api/defaults` publishes for the model's own base case. Every field is R's:
 * the value the parameter has in the scenario, the range R derives from it, the
 * domain an override stays inside, R's wording for the range, and R's verdict on
 * whether the active values are the model default or an adjusted range.
 */
export interface OwsaBound {
  id: string
  parameter: string
  model_arg: string
  /** R's heading for the input group the parameter belongs to. */
  group: string
  /** R's unit for the value, in the units the model stores it in. */
  unit: string
  /** R's range mode: "frozen width", "policy pair" or "structural scenarios". */
  range_mode: string
  /** R's short label for the scenario the range is based on. */
  range_source: string
  /** R's sentence explaining the range; shown in an InfoTip, never reworded. */
  range_rationale: string
  /** The domain an override has to stay inside, and R's step for the input. */
  min: number
  max: number
  step: number
  /** True when the value is a whole number of years. */
  integer: boolean
  /** False when this parameter's range may not be adjusted in an interface. */
  editable: boolean
  /** The value this parameter has in the submitted scenario. */
  base_value: Num
  /** R's derived range for this scenario. */
  low_default: Num
  high_default: Num
  /** The range a run uses right now: R's derived default, or a supplied range. */
  low: Num
  high: Num
  /**
   * `ok` (usable), `unavailable` (R cannot derive a range for this scenario) or
   * `invalid` (a supplied range breaks one of R's rules).
   */
  range_status: string
  /** R's sentence for a range it cannot use, otherwise "". */
  range_note: string
  /** R's sentence when a usable range no longer contains the scenario's own value. */
  range_warning: string
  /** R's verdict: "Model default" or "Adjusted". Never a client comparison. */
  range_state: string
}

/**
 * A range the user set in this session. It is sent as it stands and R decides
 * whether it can be used, so it stays absolute when a global assumption moves
 * instead of being rebased here.
 */
export interface OwsaRangeOverride {
  id: string
  low: number
  high: number
}

/**
 * The response of `POST /api/owsa-defaults`: the ranges in force for the submitted
 * scenario, derived by R without running the analysis, plus R's note about them.
 */
export interface OwsaDefaultsResponse extends Notice {
  bounds: OwsaBound[]
  bounds_note: string
}

export interface OwsaResponse extends Notice {
  outcome: OwsaOutcome
  outcome_label: string
  wtp: number
  base_outcome: Num
  base_incremental_cost: Num
  base_incremental_qalys: Num
  base_incremental_nmb: Num
  table: OwsaRow[]
  bounds: OwsaBound[]
  /** R's sentence about how the one-way ranges are derived. */
  bounds_note: string
  /**
   * R's interpretation of the run, written by summarize_eqalb_owsa(): the base case
   * and its decision reference, the parameters that move the displayed outcome
   * most, whether the conclusion survives the tested ranges, and the one-way
   * limitation, one sentence per line. Never composed or reworded in the client.
   */
  summary: string
  /** The paragraph Shiny shows above that narrative (OWSA_SUMMARY_NOTE). */
  summary_note: string
}

/** Ranking outcomes accepted by /api/owsa (see eqalb_owsa_outcome_labels). */
export type OwsaOutcome = 'inmb' | 'icer' | 'incremental_cost' | 'incremental_qalys'

export const OWSA_OUTCOMES: readonly OwsaOutcome[] = [
  'inmb',
  'incremental_qalys',
  'incremental_cost',
  'icer',
]

export const OWSA_OUTCOME_LABELS: Record<OwsaOutcome, string> = {
  inmb: 'Incremental net monetary benefit',
  incremental_qalys: 'Incremental QALYs',
  incremental_cost: 'Incremental cost',
  icer: 'ICER',
}

// --- Budget impact -----------------------------------------------------------

export interface BudgetImpactRow {
  year: number
  eligible_population: Num
  uptake_pct: Num
  cumulative_users: Num
  new_users: Num
  active_users: Num
  gross_intervention_cost: Num
  implementation_cost: Num
  healthcare_savings: Num
  avoided_event_savings: Num
  net_budget_impact: Num
  cumulative_budget_impact: Num
}

export interface BudgetImpactResponse extends Notice {
  horizon_years: number
  population: number
  table: BudgetImpactRow[]
  total_intervention_cost: Num
  total_implementation_cost: Num
  total_healthcare_savings: Num
  total_avoided_event_savings: Num
  cumulative_net_budget_impact: Num
  inputs: {
    intervention_price: Num
    implementation_cost_per_new_user: Num
    healthcare_savings_per_active_user: Num
    avoided_event_savings_per_active_user: Num
    followup_engagement_pct: Num
  }
}

// --- Simulated survival ------------------------------------------------------

export interface KmStep {
  treatment: string
  time_years: Num
  survival: Num
  lower: Num
  upper: Num
  n_risk: Num
  n_event: Num
}

export interface KmRiskRow {
  treatment: string
  year: number
  at_risk: Num
}

export interface KmSummaryRow {
  treatment: string
  patients_enrolled: Num
  events: Num
  censored: Num
  median_event_free_survival_years: Num
  event_free_at_1_year: Num
  event_free_at_5_years: Num
  event_free_at_10_years: Num
}

export interface KmDiagnosticRow {
  treatment: string
  patients_enrolled: Num
  events: Num
  censored: Num
  competing_deaths: Num
  admin_censored: Num
  event_free_observed_at_end: Num
  mean_event_time_years: Num
  median_event_time_years: Num
  event_rate_per_100: Num
  censoring_rate_per_100: Num
}

export interface KmYearlyRow {
  treatment: string
  year: number
  at_risk: Num
  cumulative_events: Num
  cumulative_censored: Num
  remaining_event_free_observed: Num
}

export interface KmCheck {
  Check: string
  Finding: string
}

/** A traffic-light status as R names it; never re-derived in the client. */
export type KmStatus = 'Green' | 'Amber' | 'Red'

/**
 * One row of the Kaplan-Meier interpretation, exactly as
 * assess_km_interpretation() in eqalb_km_interpretation.R returns it: the domain
 * name, the status R assigned and R's own explanation wording.
 */
export interface KmInterpretationDomain {
  Domain: string
  Status: KmStatus
  Explanation: string
}

/**
 * The simulated statistics the interpretation is derived from, as R's own
 * assess_km_interpretation() counted them. The three statistics that can be
 * non-estimable arrive as null.
 */
export interface KmInterpretationCounts {
  cc_events: Num
  uc_events: Num
  cc_censored: Num
  uc_censored: Num
  cc_deaths: Num
  uc_deaths: Num
  cc_admin: Num
  uc_admin: Num
  hazard_ratio: Num
  logrank_p: Num
  competing_death_p: Num
}

/**
 * R-formatted display strings (km_number() and km_p_value()). They are shown as
 * returned so the panel prints the same text as the Shiny tab, including
 * "not estimable" and format.pval()'s "<0.001".
 */
export interface KmInterpretationDisplay {
  hazard_ratio: string
  logrank_p: string
  competing_death_p: string
}

/** The complete result of assess_km_interpretation(), unchanged. */
export interface KmInterpretation {
  overall_status: KmStatus
  domains: KmInterpretationDomain[]
  counts: KmInterpretationCounts
  /** R's plain-language summary of the run. */
  interpretation: string
  /** R's traffic-light rules for this panel, one sentence per rule. */
  rules: string[]
  display: KmInterpretationDisplay
}

export interface SurvivalResponse extends Notice {
  n_per_arm: number
  followup_years: number
  seed: number
  rrr: Num
  engagement_year1: Num
  engagement_followup: Num
  steps: KmStep[]
  risk_table: KmRiskRow[]
  summary: KmSummaryRow[]
  diagnostics: { summary: KmDiagnosticRow[]; yearly: KmYearlyRow[] }
  /** Modelled (analytic) event counts per arm. */
  expected_events: Record<string, Num>
  arm_contrast: {
    checks: KmCheck[]
    logrank_p: Num
    hazard_ratio_cc_vs_uc: Num
    verdict: string
  }
  /** The traffic-light interpretation, derived by R from the statistics above. */
  interpretation: KmInterpretation
  /**
   * R's descriptive log-rank line, including the simulated-data notice, so the
   * panel never shows the p-value without its qualifier.
   */
  logrank_note: string
  event_note: string
}

// --- Value of information ----------------------------------------------------

export interface VoiEvpi {
  mean_incremental_cost: Num
  mean_incremental_qalys: Num
  mean_nmb: Num
  expected_nmb_perfect: Num
  expected_nmb_current: Num
  evpi: Num
}

export interface EvppiRow {
  parameter: string
  model_argument: string
  evppi: Num
  evppi_raw: Num
  clamped: boolean
}

/**
 * EVPPI needs at least 100 successful PSA draws; below that the R layer returns
 * an explanation instead of a table.
 */
export type EvppiResult =
  | { available: false; reason: string }
  | { available: true; table: EvppiRow[] }

export interface VoiResponse extends Notice {
  wtp: number
  n: number
  evpi: VoiEvpi
  evppi: EvppiResult
}

// --- DHT readiness ----------------------------------------------------------

/** Readiness inputs in the units calculate_readiness() expects (percentages). */
export interface ReadinessInputs {
  target_population?: number
  /** Percentage, 0-100. */
  digital_access?: number
  /** Percentage, 0-100. */
  digital_suitability?: number
  /** Percentage, 0-100. */
  readiness_year1_engagement?: number
  /** Percentage, 0-100. */
  readiness_followup_engagement?: number
  /** Minutes per patient per month. */
  review_minutes?: number
  supported_languages?: number
  accessibility_features?: boolean
  /** One of readiness.choices.interoperability.levels from /api/defaults. */
  interoperability?: string
  /** One of readiness.choices.algorithm_governance.levels from /api/defaults. */
  algorithm_governance?: string
}

export type ReadinessStatus = 'Green' | 'Amber' | 'Red'

/** One row of the quantitative readiness outputs (values are formatted in R). */
export interface ReadinessNumbersRow {
  Measure: string
  Value: string
  'Illustrative basis': string
}

/** One row of the seven-domain assessment. */
export interface ReadinessDomainRow {
  Domain: string
  Status: ReadinessStatus
  'Current input': string
  Interpretation: string
}

/** One of the five status cards the Shiny readiness tab shows. */
export interface ReadinessCardRow {
  Domain: string
  Status: ReadinessStatus
  Explanation: string
}

export interface ReadinessCounts {
  Green: number
  Amber: number
  Red: number
}

/**
 * Response of /api/readiness: the calculate_readiness() object unchanged, plus
 * the notice. `engagement_retention_pct` is null when year-1 engagement is 0,
 * which the interpretation reports as "NA (year-1 engagement is 0)".
 */
export interface ReadinessResponse extends Notice {
  eligible_population: Num
  active_users_year1: Num
  active_users_followup: Num
  engagement_retention_pct: Num
  annual_clinician_hours: Num
  numbers: ReadinessNumbersRow[]
  domains: ReadinessDomainRow[]
  cards: ReadinessCardRow[]
  counts: ReadinessCounts
  interpretation: string
}

// --- HTA decision summary ----------------------------------------------------

/**
 * A dashboard status. "Not available" is what assess_hta_decision_summary()
 * returns when the values a domain needs were not supplied; it is never a guess
 * and must not be rendered as a traffic light.
 */
export type HtaSummaryStatus = 'Green' | 'Amber' | 'Red' | 'Not available'

export interface HtaSummaryDomainRow {
  Domain: string
  Status: HtaSummaryStatus
  Measure: string
  Basis: string
  Interpretation: string
}

/** One row of the evidence-priority table, formatted in R. */
export interface HtaEvidencePriorityRow {
  'Evidence gap': string
  'Current model signal': string
  'Current status': string
  'Why it matters': string
  'Evidence needed': string
  'Suggested study or data source': string
  /** "Not yet available" when the driving output has not been computed. */
  Priority: 'High' | 'Medium' | 'Low' | 'Not yet available'
  'Dashboard domain affected': string
}

/**
 * Which upstream analyses were supplied. `missing_inputs` names the request
 * fields behind the unassessed domains and is `null` when nothing is missing
 * (R builds it as an empty vector, which R serialises as null); the domain lists
 * are read back from the R summary rather than derived here.
 */
export interface HtaSummaryAvailability {
  base_case: boolean
  psa: boolean
  value_of_information: boolean
  budget_impact: boolean
  readiness: boolean
  missing_inputs: string[] | null
  not_assessable_domains: string[]
  assessed_domains: number
}

/**
 * Request of /api/hta-summary. Every field is optional: an omitted value means
 * that analysis has not been run, and R reports the not-yet-available wording.
 * Values the other endpoints already produced are passed through unchanged
 * (icer from /api/base-case, probability_cost_effective, mean_incremental_nmb,
 * evpi and evppi_table from /api/psa and /api/value-of-information, the budget
 * impact values from /api/budget-impact), and `readiness` carries the same
 * inputs as /api/readiness. Domain statuses are deliberately not accepted.
 * The scenario fields are the evidence-priority signals; like every other
 * endpoint's inputs they fall back to the model's base-case constants in R, so
 * they are optional here.
 */
export interface HtaSummaryInputs extends Partial<ScenarioInputs> {
  /** Reference WTP threshold; may also be sent as the `wtp` query parameter. */
  wtp?: number
  icer?: number
  probability_cost_effective?: number
  mean_incremental_nmb?: number
  evpi?: number
  highest_evppi?: number
  cumulative_budget_impact?: number
  bia_intervention_cost?: number
  bia_implementation_cost?: number
  bia_healthcare_savings?: number
  evppi_table?: Array<{ parameter: string; evppi: number }>
  readiness?: ReadinessInputs
}

/**
 * Response of /api/hta-summary: assess_hta_decision_summary() and
 * build_hta_evidence_priorities() unchanged, plus availability metadata and the
 * notice. `overall_status` is "Not available" and `position` is
 * "Not yet assessable" when too little has been run for a position to exist.
 */
export interface HtaSummaryResponse extends Notice {
  wtp: number
  summary: {
    domains: HtaSummaryDomainRow[]
    overall_status: HtaSummaryStatus
    position: string
    interpretation: string
  }
  evidence_priorities: {
    table: HtaEvidencePriorityRow[]
    summary: string
  }
  /**
   * The rules behind the statuses, verbatim from eqalb_ui_copy.R: the popover
   * items the Shiny dashboard shows (HTA_RULE_ITEMS), the note under the
   * evidence-priority table (HTA_EVIDENCE_NOTE) and the single-paragraph rule
   * summary that also goes into the exported results package
   * (HTA_SUMMARY_RULE_NOTE).
   */
  rules: string[]
  evidence_note: string
  rule_note: string
  availability: HtaSummaryAvailability
}

// --- Value-based price -------------------------------------------------------

/**
 * One level of a scan axis. `role` is the model's own wording for the level
 * ("low bound", "scenario", "high bound", or a combination when the scenario's
 * value coincides with a bound) and `label` is R's label for it, e.g.
 * "5% (low bound)".
 */
export interface PriceScanLevel {
  value: number
  role: string
  label: string
}

/** One scan axis: the model's bound id, its parameter name and its levels. */
export interface PriceScanAxis {
  id: string
  parameter: string
  model_arg: string
  unit: string
  scenario_value: number
  levels: PriceScanLevel[]
}

/** One cell of the scan: the supported price under one pair of assumptions. */
export interface PriceScanCell {
  row_value: number
  row_label: string
  column_value: number
  column_label: string
  incremental_cost: Num
  incremental_qalys: Num
  /** null when no non-negative price reaches the reference threshold. */
  max_acceptable_price: Num
  /** The raw solved price, reported even when it is not a usable price. */
  solved_price: Num
  headroom_eur: Num
  headroom_pct: Num
  price_supported: boolean | null
  /** R's status band: "Green", "Red" or "Not available". */
  status: string
  available: boolean
  /** R's explanation when the cell could not be identified; "" otherwise. */
  warning: string
}

/** The best or worst identified cell of the scan, named in R. */
export interface PriceScanEndpoint {
  row_label: string | null
  column_label: string | null
  max_acceptable_price: Num
  status: string | null
}

/** The illustrative scan of the supported price across the model's own bounds. */
export interface PriceScan {
  row_axis: PriceScanAxis
  column_axis: PriceScanAxis
  cells: PriceScanCell[]
  cells_total: number
  cells_available: number
  cells_supporting_current_price: number
  best: PriceScanEndpoint
  worst: PriceScanEndpoint
  /** R's plain-language summary of the scan. */
  summary: string
  /** R's statement of what the scan holds fixed. */
  note: string
}

/**
 * The price solve. `status` is R's band for the current price: Green when the
 * model run at `current_price` reaches the reference threshold, Red when it does
 * not, "Not available" when the model did not return the values the comparison
 * needs. `max_acceptable_price` is null when no non-negative price reaches the
 * threshold, and `solved_price` then carries the raw root.
 */
export interface PriceHeadline {
  available: boolean
  /** "affine_price_solve_verified", "bisection_fallback" or "not_available". */
  method: string
  max_acceptable_price: Num
  solved_price: Num
  verified: boolean | null
  verification_nmb: Num
  price_cost_slope: Num
  cost_without_price: Num
  incremental_cost: Num
  incremental_qalys: Num
  icer: Num
  incremental_nmb: Num
  zero_price_nmb: Num
  price_supported: boolean | null
  status: string
  /** R's explanation when the solve could not identify a price; "" otherwise. */
  reason: string
  headroom_eur: Num
  headroom_pct: Num
  interpretation: string
}

/**
 * The relative risk reduction the current price would need. `verdict` is the
 * machine-readable state — "met" when the scenario's own reduction already
 * reaches the threshold, "not_met" when a higher one is required (or when none
 * within the model's domain is enough) and "not_available" when the model did not
 * run — and `verdict_label` is the same state in R's user-facing words ("Met",
 * "Not met", "Not available"). Both come from R; the interface shows the label.
 */
export interface RequiredEffect {
  available: boolean
  verdict: 'met' | 'not_met' | 'not_available'
  /** R's user-facing wording for `verdict`: "Met", "Not met", "Not available". */
  verdict_label: string
  required_rrr: Num
  required_rrr_pct: Num
  current_rrr: Num
  current_rrr_pct: Num
  /** Whether the requirement lies inside the model's one-way range. */
  within_sensitivity_range: boolean | null
  /** Bisection bracket width of the reported value, in the fraction itself. */
  precision_rrr: Num
  verification_nmb: Num
  reason: string
  interpretation: string
}

/** The scenario the analysis ran, with R's own derived percentages. */
export interface PriceScenario {
  rrr: number
  rrr_pct: number
  engagement_year1: number
  engagement_year1_pct: number
  engagement_followup: number
  engagement_followup_pct: number
  incremental_cost: Num
  incremental_qalys: Num
  icer: Num
  incremental_nmb: Num
  price_cost_slope: Num
  cost_without_price: Num
  price_cost_contribution: Num
}

/**
 * Which results R could identify, and why an unavailable one is unavailable.
 * `missing_inputs` lists request fields the analysis needs that were not supplied
 * and have no model default; over HTTP every model input has one, so it is empty.
 */
export interface ValueBasedPriceAvailability {
  max_acceptable_price: boolean
  required_effect: boolean
  /** True only when every scan cell could be identified. */
  grid: boolean
  grid_cells_available: number
  grid_cells_total: number
  missing_inputs: string[]
  reasons: {
    max_acceptable_price: string
    required_effect: string
    grid: string
  }
}

/**
 * Response of /api/value-based-price: the calculate_value_based_price() result
 * from eqalb_price.R unchanged, plus the resolved inputs, any request warnings
 * (a `current_price` that overrides the scenario price) and the notice. Every
 * number, status, label and sentence is R's; the client derives nothing.
 *
 * `method` and `method_note` are engineering provenance: the solver R used and
 * how it works. They are part of the contract for API callers and for the
 * exported package, and the interface deliberately does not render them.
 */
export interface ValueBasedPriceResponse extends Notice {
  analysis: string
  /** Engineering provenance — the solver that produced the price. Not rendered. */
  method: string
  /** Engineering provenance — how the solver works. Not rendered. */
  method_note: string
  wtp: number
  current_price: Num
  status: string
  scenario: PriceScenario
  headline: PriceHeadline
  required_effect: RequiredEffect
  grid: PriceScan
  availability: ValueBasedPriceAvailability
  interpretation: string
  /** R's one-way qualification of these figures, shown with the results. */
  limitation: string
  inputs: Record<string, Num>
  warnings: string[]
}

// --- Guided Tutorial Part 1 --------------------------------------------------
//
// The tutorial is a presentation layer over eqalb_tutorial.R: every default,
// range, label, status, threshold, interpretation and formatted string the four
// steps show arrives from `GET /api/tutorial` (the contract) or
// `POST /api/tutorial/part1` (the results). Nothing here derives, classifies or
// rewords a tutorial value, and the tutorial never shares state with the
// analysis dashboard.

/** A tutorial traffic light. `Not assessed` is what R reports when it has none. */
export type TutorialStatus = 'Green' | 'Amber' | 'Red' | 'Not assessed'

/** The tutorial's own control ids, as R names them. */
export interface TutorialInputs {
  tutorial_price?: number
  tutorial_rrr?: number
  tutorial_engagement_year1?: number
  tutorial_engagement_followup?: number
  tutorial_utility_no_event?: number
  tutorial_population?: number
  tutorial_review_minutes?: number
  tutorial_interop_available?: boolean
  tutorial_language_available?: boolean
}

/** One control, exactly as R describes it (label, unit, range, step, help). */
export interface TutorialControl {
  id: keyof TutorialInputs
  /** The tutorial step the control belongs to, 1-based. */
  step_index: number
  type: 'slider' | 'checkbox'
  label: string
  unit: string
  /** What the explanation is about, for the help trigger's accessible name. */
  info_topic: string
  /** R's own explanation, verbatim from the interface-copy dictionary. */
  info: string
  default: number | boolean
  /** Bounds and step are absent for a checkbox. */
  min?: number
  max?: number
  step?: number
}

/**
 * The static wording of one tutorial step. Which keys are present depends on the
 * step, exactly as R builds it; the step components read the ones they render.
 */
export interface TutorialStepCopy {
  id: string
  title: string
  progress: string
  intro: string
  explain: string[]
  controls_heading?: string
  fixed_title?: string
  fixed_hint?: string
  result_heading?: string
  heading_info_key?: string
  heading_info_topic?: string
  linked_price_label?: string
  disclosure_label?: string
  domains_heading?: string
  engagement_note?: string
  conditions_heading?: string
  conditions_note?: string
  rules_trigger_label?: string
  rules_title?: string
  summary_heading?: string
  interpretation_heading?: string
  evidence_heading?: string
  finish_label?: string
}

export interface TutorialContract {
  title: string
  kicker: string
  disclaimer: string
  progress: {
    total: number
    step_template: string
    completed_template: string
  }
  navigation: { back: string; forward: string; exit: string }
  completion: {
    title: string
    body: string
    open_full_label: string
    restart_label: string
  }
  controls: TutorialControl[]
  /** Every control's tutorial default, keyed by control id. */
  defaults: Record<string, number | boolean>
  /** The explanations that belong to a step heading, keyed as the steps name them. */
  headings: Record<string, string>
  /** R's own column headings for the tutorial's tables. */
  table_headings: {
    measure: string
    value: string
    basis: string
    year: string
    active_users: string
    net_budget_impact: string
    current_values: string
  }
  fixed: {
    /** The tutorial's fixed R-owned values, echoed for transparency. */
    values: Record<string, number | string | boolean>
    post_event_utilities: { title: string; items: string[]; hint: string }
  }
  steps: TutorialStepCopy[]
  rules: { title: string; trigger_label: string; items: string[] }
  evidence: { heading: string; items: string[] }
  labels: {
    current_values: string
    readiness_checks: string
    overall_status_prefix: string
    overall_note: string
    overall_fallback_status: string
  }
}

export interface TutorialResponse extends Notice {
  part1: TutorialContract
}

/** One row of the Step-1 result table, already formatted by R. */
export interface TutorialCeTableRow {
  measure: string
  value: string
}

/** One plotted point of the cost-effectiveness plane. */
export interface TutorialPlanePoint {
  label: string
  incremental_cost: number
  incremental_qalys: number
}

export interface TutorialCe {
  incremental_cost: number
  incremental_qalys: number
  /** Null when R reported the ratio as not interpretable. */
  icer: Num
  /** R's rendering of the ratio, including its own unavailable wording. */
  icer_display: string
  table: TutorialCeTableRow[]
  chart: {
    title: string
    subtitle: string
    x_label: string
    y_label: string
    points: TutorialPlanePoint[]
  }
}

/** One row of the Step-2 annual table, already formatted by R. */
export interface TutorialBiaTableRow {
  year: number
  active_users: string
  net_budget_impact: string
}

export interface TutorialBia {
  horizon_years: number
  total: number
  total_display: string
  /** R's one-line five-year total, as the step shows it. */
  total_sentence: string
  /** R's own sentence naming the Step-1 price this step used. */
  linked_price_sentence: string
  /** The chart series, with the same rows `POST /api/budget-impact` returns. */
  rows: BudgetImpactRow[]
  table: TutorialBiaTableRow[]
  chart: { title: string; subtitle: string; x_label: string; y_label: string }
}

export interface TutorialReadinessCard {
  domain: string
  status: TutorialStatus
  explanation: string
}

export interface TutorialReadinessNumber {
  measure: string
  value: string
  basis: string
}

/** One assessed readiness domain, as `calculate_readiness()` returns it. */
export interface TutorialReadinessDomainRow {
  Domain: string
  Status: TutorialStatus
  'Current input': string
  Interpretation: string
}

export interface TutorialReadiness {
  cards: TutorialReadinessCard[]
  /** The domains the tutorial shows (algorithm governance is excluded in R). */
  domains: TutorialReadinessDomainRow[]
  numbers: TutorialReadinessNumber[]
  /** R's own sentence naming the two domains the Step-3 answers set. */
  checks_sentence: string
  green_domain_count: number
  domain_count: number
}

export interface TutorialSummaryRow {
  domain: string
  status: TutorialStatus
  /** R's "current values" line for the domain. */
  measure: string
  interpretation: string
}

export interface TutorialSummary {
  overall_status: TutorialStatus
  /** R's heading for the overall card, with the status already in it. */
  overall_title: string
  rows: TutorialSummaryRow[]
  interpretation: string
}

export interface TutorialPart1Response extends Notice {
  /** The values the response was evaluated with, after R applied its defaults. */
  inputs: Required<TutorialInputs>
  /** The tutorial's fixed R-owned values, so they can be checked at a glance. */
  fixed_inputs: Record<string, number | string | boolean>
  ce: TutorialCe
  bia: TutorialBia
  readiness: TutorialReadiness
  summary: TutorialSummary
}

// --- Guided Tutorial Part 2 --------------------------------------------------
//
// Part 2 is the commissioning case challenge. Like Part 1 it is a presentation
// layer over eqalb_tutorial.R: the case, its facts, the price curve, every
// pass/fail classification, the highest acceptable price, the chart's labels and
// colours and all instructional wording arrive from R. The case is identified by
// an opaque handle R issues; the client stores and echoes it and never selects,
// infers or names a case itself.

/** The five Part 2 sections, in teaching order. */
export type Part2SectionKey = 'brief' | 'value' | 'budget' | 'readiness' | 'recommend'

export interface Part2Section {
  key: Part2SectionKey
  name: string
  /** False for the sections this slice does not implement yet. */
  available: boolean
}

/** One read-only case fact, grouped as R groups it. */
export interface Part2CaseFact {
  group: string
  fact: string
  value: string
}

/** One point of the price curve, with R's own classification of it. */
export interface Part2CurvePoint {
  price: number
  /** Stable R-provided identifier; charts key on this, never on an index. */
  key: string
  incremental_cost: number
  incremental_qalys: number
  icer: Num
  /** R's rendering of the ratio, including its unavailable wording. */
  icer_display: string
  /** Which of R's two series the point belongs to. */
  series_key: 'meets' | 'above'
  meets: boolean
}

export interface Part2Curve {
  /** The case this curve belongs to; R requires it to match on a posted curve. */
  case_id: string
  points: Part2CurvePoint[]
  point_count: number
  max_acceptable_price: Num
  max_acceptable_price_display: string
  threshold: number
  /** Present only when the curve was posted back rather than recomputed. */
  source?: string
}

export interface Part2ChartSeries {
  key: string
  label: string
  colour: string
}

export interface Part2Chart {
  title: string
  caption: string
  x_label: string
  y_label: string
  series: Part2ChartSeries[]
  threshold_line: { value: number; colour: string; dash: string; label: string }
  marker: { colour: string; label: string }
}

export interface Part2PriceStates {
  [state: string]: { label: string; message: string }
}

export interface Part2PriceStrings {
  task: string
  note: string
  lever_hint: string
  method_note: string
  states: Part2PriceStates
  below_max_hint: string
  maximum_label: string
  threshold_label: string
  chart: Part2Chart
}

/** One annual budget-impact row, with R's formatted strings and series values. */
export interface Part2BudgetRow {
  year: number
  /** Stable R-provided key; charts and tables map on this, never on an index. */
  key: string
  eligible_population: number
  uptake_pct: number
  cumulative_users: number
  new_users: number
  active_users: number
  active_users_display: string
  gross_intervention_cost: number
  implementation_cost: number
  healthcare_savings: number
  avoided_event_savings: number
  net_budget_impact: number
  net_budget_impact_display: string
  cumulative_budget_impact: number
  cumulative_display: string
}

/** The budget-impact wording and table headings, all R's. */
export interface Part2BudgetStrings {
  task: string
  note: string
  scope_note: string
  lever_label: string
  coverage_label: string
  coverage_sentence_template: string
  population_template: string
  covered_template: string
  full_rollout_template: string
  states: Part2PriceStates
  maximum_label: string
  maximum_none: string
  maximum_reached_hint: string
  increase_hint: string
  summary_template: string
  chart: {
    title: string
    caption: string
    x_label: string
    y_label: string
    cumulative_label: string
    annual_label: string
    cost_label: string
    saving_label: string
  }
  table: {
    disclosure_label: string
    caption: string
    headings: {
      year: string
      activated_users: string
      net_budget_impact: string
      cumulative: string
    }
  }
  price_shortcut_label: string
  price_shortcut_note: string
}

/** The budget-impact result at one coverage cap, with R's affordability state. */
export interface Part2BudgetResult {
  coverage: number
  covered_population: number
  population: number
  horizon_years: number
  total: number
  total_display: string
  affordable: boolean
  at_max: boolean
  state: 'at_max' | 'below_max' | 'over'
  state_label: string
  state_message: string
  state_hint: string
  max_affordable_coverage: Num
  max_affordable_coverage_display: string
  budget_ceiling: number
  budget_ceiling_display: string
  rows: Part2BudgetRow[]
  summary: string
  population_sentence: string
  covered_sentence: string
  full_rollout_sentence: string
  coverage_sentence: string
  lever_sentence: string
  price_shortcut: { show: boolean; label: string; note: string }
  strings: Part2BudgetStrings
}

export interface Part2Control {
  id: string
  type: 'slider'
  label: string
  unit: string
  info_topic: string
  info: string
  default: number
  min: number
  max: number
  step: number
}

/** The same control as a case response carries it: with its current value. */
export interface Part2CaseControl {
  id: string
  label: string
  unit: string
  min: number
  max: number
  step: number
  value: number
}

/** The Part 2 contract: everything needed before a case exists. */
export interface Part2Contract {
  title: string
  kicker: string
  sections: Part2Section[]
  available_sections: string[]
  coming_next_label: string
  coming_next_note: string
  entry_label: string
  entry_note: string
  entry_busy_label: string
  progress: { total: number; step_template: string; available_template: string }
  navigation: { back: string; forward: string; exit: string }
  case_banner_template: string
  case_facts: {
    button_label: string
    title_template: string
    close_label: string
    table_headings: { group: string; fact: string; value: string }
    hint: string
  }
  brief: {
    heading: string
    controls_heading: string
    intro_template: string
    policy: string
    levers: string
    facts_hint: string
    start_label: string
  }
  value: { heading: string; result_heading: string }
  budget: {
    heading: string
    result_heading: string
    coverage_control: Part2Control
  }
  fixed: {
    threshold: number
    threshold_display: string
    budget_ceiling: number
    budget_ceiling_display: string
    manufacturer_minimum_price: number
    manufacturer_minimum_price_display: string
  }
  price_control: Part2Control
  price: Part2PriceStrings
  /** The budget-impact wording the section and its disclosure render. */
  budget_impact: Part2BudgetStrings
  status_available: string
  icer_unavailable: string
  limitation: string
}

export interface TutorialPart2ContractResponse extends Notice {
  part2: Part2Contract
}

/** Case identity as R describes it; `banner` is R's own sentence. */
export interface Part2CaseIdentity {
  case_id: string
  label: string
  title: string
  heading: string
  banner: string
  facts: Part2CaseFact[]
}

export interface Part2CaseResponse extends Notice {
  case: Part2CaseIdentity & { summary: string }
  brief: { intro: string }
  price: { control: Part2CaseControl; curve: Part2Curve }
  /** The coverage lever's starting value and the case's budget result at it. */
  budget: Part2BudgetResult & { control: Part2CaseControl }
  /** Fixed per-case inputs the later sections will use. */
  later_inputs: {
    population: number
    review_minutes: number
    followup_engagement_pct: number
    year1_engagement_pct: number
    languages: number
    language_available: boolean
  }
  strings: { price: Omit<Part2PriceStrings, 'states' | 'threshold_label' | 'chart'>; chart: Part2Chart }
  selection: { rule: string; candidates: number; excluded: string }
}

/** The current-price result: R's state, its detail and its nudge. */
export interface Part2PriceResult {
  price: number
  price_display: string
  passed: boolean
  at_max: boolean
  state: 'at_max' | 'below_max' | 'over'
  state_label: string
  state_message: string
  state_hint: string
  incremental_cost: number
  incremental_qalys: number
  icer: Num
  icer_display: string
  detail: string
  threshold: number
}

/** One domain of R's readiness assessment: its name and its own status. */
export interface Part2ReadinessDomain {
  domain: string
  status: TutorialStatus
}

/** One reach or workload figure R's readiness assessment produced. */
export interface Part2ReadinessNumber {
  measure: string
  value: string
}

/** The four DHT readiness questions, as R's own field names. */
export type Part2ReadinessField =
  | 'interoperability'
  | 'governance'
  | 'clinical_workflow'
  | 'patient_engagement'

export type Part2ReadinessChoices = Record<Part2ReadinessField, string>

/**
 * R's DHT readiness exercise result: the answers R used, the readiness inputs R
 * mapped them onto, each domain's status, the reach and workload figures, the
 * deliverability verdict and R's calculation-dependent sentences. The client
 * renders it and decides nothing.
 */
export interface Part2ReadinessResult {
  choices: Part2ReadinessChoices
  inputs: {
    interoperability: string
    algorithm_governance: string
    review_minutes: number
    followup_engagement_pct: number
  }
  domains: Part2ReadinessDomain[]
  numbers: Part2ReadinessNumber[]
  deliverability: { passed: boolean; label: string }
  note: string
  engagement_note: string
}

/**
 * R's commissioning outcome, chosen in R from the value-for-money, affordability
 * and readiness results and the selected coverage cap. The headline and the
 * message are R's own wording, and `complete` is true only for the
 * conditional-adoption outcome, so the client never infers either.
 */
export interface Part2Recommendation {
  status:
    | 'do_not_recommend'
    | 'negotiate_price'
    | 'resolve_barriers'
    | 'increase_coverage'
    | 'conditional_adoption'
  headline: string
  message: string
  /** True only for the conditional-adoption outcome. */
  complete: boolean
}

export interface Part2EvaluateResponse extends Notice {
  case: Part2CaseIdentity
  price: Part2PriceResult
  maximum: { value: Num; display: string; label: string; reached: boolean }
  curve: Part2Curve
  /** The budget-impact result at the coverage cap this request used. */
  budget: Part2BudgetResult
  /** The readiness exercise's result at the four answers this request sent. */
  readiness: Part2ReadinessResult
  /** R's commissioning outcome for the same results and coverage cap. */
  recommendation: Part2Recommendation
  /** R's marker: its price, colour, label and stable key. */
  marker: { price: number; key: string; colour: string; label: string }
  chart: Part2Chart
  answer: string
  strings: { task: string; note: string; lever_hint: string; method_note: string }
  section: { key: Part2SectionKey; name: string; step_index: number; available: boolean }
  limitation: string
  /** Which path produced the curve. Provenance only; not rendered. */
  curve_source: string
}

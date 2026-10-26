# eQalb model API
#
# Thin HTTP wrapper around the existing, verified R model modules. This file
# contains NO model arithmetic: every endpoint validates its inputs, calls a
# function from eqalb_markov.R / eqalb_owsa.R / eqalb_survival.R /
# eqalb_readiness.R, and returns JSON. The Shiny app (app.R) remains the
# reference implementation.
#
# Two ways to serve it, both on 127.0.0.1:8788 (run only one at a time):
#
#   1. FastAPI, the primary service: `api\.venv\Scripts\python.exe api\run_api.py`.
#      It starts api/r_worker.R, which parses this file with plumber and then
#      calls the route handlers below directly over a JSON-lines pipe, so the
#      endpoint logic stays in one place and no model code is duplicated in
#      Python. See api/main.py and api/r_client.py.
#   2. The plain plumber HTTP service: `Rscript api\run_api.R`. Kept as a
#      no-Python fallback and as a way to compare the two stacks; it serves the
#      identical endpoints.
#
# Because the handlers are reused, keep them free of HTTP-server assumptions:
# each one reads req$postBody, req$argsQuery and req$REQUEST_METHOD and returns a
# plain list. api/r_worker.R builds exactly those three fields.
#
# Response conventions
#   - Every response carries `notice`, the simulated-data disclaimer.
#   - Missing or non-finite numbers are returned as JSON null, never as
#     "Infinity"/"NaN", so the client can distinguish "not interpretable" from a
#     real value.
#   - Full numeric precision is preserved (no 4-digit rounding).

# --- Model module loading ----------------------------------------------------

# The root is normally set by run_api.R (it also publishes the
# `eqalb.api.root` option). The fallback keeps this file usable when it is
# parsed by plumber from another working directory.
resolve_api_root <- function() {
  root <- getOption("eqalb.api.root", NULL)
  if (!is.null(root) && file.exists(file.path(root, "eqalb_markov.R"))) {
    return(normalizePath(root))
  }
  candidates <- c(getwd(), file.path(getwd(), "api"), file.path(getwd(), ".."))
  found <- candidates[file.exists(file.path(candidates, "eqalb_markov.R"))]
  if (length(found) > 0L) normalizePath(found[[1]]) else normalizePath(getwd())
}

if (!exists("API_ROOT", inherits = FALSE)) {
  API_ROOT <- resolve_api_root()
}

MODEL_MODULES <- c(
  "eqalb_markov.R", "eqalb_owsa.R", "eqalb_survival.R", "eqalb_readiness.R",
  "eqalb_km_interpretation.R", "eqalb_ui_copy.R", "eqalb_price.R",
  "eqalb_tutorial.R", "eqalb_tutorial_journey.R"
)

# Wrapped in a function on purpose: eqalb_markov.R ends its demo/analysis block
# with `if (sys.nframe() == 0L)`, and sourcing from inside a function keeps the
# frame count above zero so the interactive demo block does not run here.
load_model_modules <- function(root = API_ROOT) {
  missing <- MODEL_MODULES[!file.exists(file.path(root, MODEL_MODULES))]
  if (length(missing) > 0L) {
    stop(
      "Model module(s) not found in ", root, ": ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  for (module in MODEL_MODULES) {
    sys.source(file.path(root, module), envir = globalenv())
  }
  invisible(TRUE)
}

if (!exists("run_eqalb_model", inherits = FALSE)) {
  load_model_modules()
}

MODEL_FUNCTIONS <- c(
  "run_eqalb_model", "summarize_model", "run_psa_eqalb", "psa_parameter_table",
  "calculate_budget_impact", "voi_evpi", "voi_evppi", "run_eqalb_owsa",
  "summarize_eqalb_owsa", "eqalb_owsa_parameters", "eqalb_owsa_base_args",
  "eqalb_owsa_range_bounds", "simulate_eqalb_survival",
  "summarize_eqalb_survival", "diagnose_eqalb_survival",
  "expected_eqalb_events", "assess_eqalb_arm_contrast", "calculate_readiness",
  "assess_km_interpretation", "km_number", "km_p_value",
  "calculate_value_based_price", "eqalb_tutorial_contract",
  "eqalb_tutorial_part1", "eqalb_tutorial_part2_contract",
  "eqalb_tutorial_part2_case", "eqalb_tutorial_part2_evaluate",
  "eqalb_journey_contract", "eqalb_journey_base_case",
  "eqalb_journey_uncertainty", "eqalb_journey_sensitivity",
  "eqalb_journey_price", "eqalb_journey_budget", "eqalb_journey_readiness",
  "eqalb_journey_survival"
)

# --- Small helpers -----------------------------------------------------------

simulated_notice <- function() {
  get0(
    "SIMULATED_DATA_NOTICE",
    envir = globalenv(),
    ifnotfound = "Simulated illustrative data - not clinical evidence"
  )
}

scalar_out <- function(value) {
  if (is.null(value) || length(value) != 1L) {
    return(NA_real_)
  }
  value <- suppressWarnings(as.numeric(value))
  if (is.na(value) || !is.finite(value)) NA_real_ else value
}

vector_out <- function(value) {
  value <- suppressWarnings(as.numeric(value))
  value[!is.finite(value)] <- NA_real_
  value
}

parse_body <- function(req) {
  body <- req$postBody
  if (is.null(body) || !nzchar(body)) {
    return(list())
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(body, simplifyVector = TRUE),
    error = function(error) NULL
  )
  if (is.null(parsed) || !is.list(parsed) || is.null(names(parsed))) {
    stop("The request body must be a JSON object.", call. = FALSE)
  }
  parsed
}

as_number <- function(value, name, default, min = -Inf, max = Inf) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    value <- default
  }
  if (is.null(value)) {
    stop(sprintf("'%s' is required.", name), call. = FALSE)
  }
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    stop(sprintf("'%s' must be a single finite number.", name), call. = FALSE)
  }
  if (value < min || value > max) {
    stop(
      sprintf("'%s' must be between %s and %s.", name, format(min), format(max)),
      call. = FALSE
    )
  }
  value
}

query_number <- function(req, name, default, min = -Inf, max = Inf) {
  as_number(req$argsQuery[[name]], name, default, min = min, max = max)
}

body_number <- function(body, name, default, min = -Inf, max = Inf) {
  as_number(body[[name]], name, default, min = min, max = max)
}

# Boolean counterpart of body_number, for checkbox-style inputs. Accepts a JSON
# boolean, 0/1, or "true"/"false", because jsonlite may deliver either form.
as_flag <- function(value, name, default) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(default)
  }
  if (is.logical(value)) {
    return(value)
  }
  if (is.numeric(value) && value %in% c(0, 1)) {
    return(value == 1)
  }
  text <- tolower(trimws(as.character(value)))
  if (text %in% c("true", "yes", "1")) {
    return(TRUE)
  }
  if (text %in% c("false", "no", "0")) {
    return(FALSE)
  }
  stop(sprintf("'%s' must be true or false.", name), call. = FALSE)
}

body_flag <- function(body, name, default) {
  as_flag(body[[name]], name, default)
}

# Choice counterpart of body_number, for select-style inputs whose valid values
# are defined by the readiness module.
as_choice <- function(value, name, choices, default) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(default)
  }
  text <- as.character(value)
  if (!text %in% choices) {
    stop(
      sprintf("'%s' must be one of: %s", name, paste(choices, collapse = ", ")),
      call. = FALSE
    )
  }
  text
}

body_choice <- function(body, name, choices, default) {
  as_choice(body[[name]], name, choices, default)
}

# Optional counterpart of body_number for values a caller may not have yet, such
# as the output of an analysis that has not been run. An absent (or null) field
# stays NA_real_, which is how the HTA decision-summary functions read "no value
# supplied": nothing is filled in with a number the caller never measured.
optional_number <- function(value, name, min = -Inf, max = Inf) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    return(NA_real_)
  }
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    stop(sprintf("'%s' must be a single finite number.", name), call. = FALSE)
  }
  if (value < min || value > max) {
    stop(
      sprintf("'%s' must be between %s and %s.", name, format(min), format(max)),
      call. = FALSE
    )
  }
  value
}

body_optional_number <- function(body, name, min = -Inf, max = Inf) {
  optional_number(body[[name]], name, min = min, max = max)
}

# Builds the full argument list of run_eqalb_model() from the request body,
# falling back to the model's own base-case constants. `overrides` wins over the
# body and is used by endpoints that reuse one parameter set.
scenario_args <- function(body = list(), overrides = list()) {
  pick <- function(name) {
    if (!is.null(overrides[[name]])) overrides[[name]] else body[[name]]
  }
  list(
    scenario_intervention_price = as_number(
      pick("intervention_price"), "intervention_price",
      intervention_price_annual, min = 0, max = 1e6
    ),
    scenario_implementation_cost = as_number(
      pick("implementation_cost"), "implementation_cost",
      implementation_cost, min = 0, max = 1e6
    ),
    scenario_healthcare_savings = as_number(
      pick("healthcare_savings"), "healthcare_savings",
      healthcare_use_savings_annual, min = 0, max = 1e6
    ),
    scenario_rrr = as_number(pick("rrr"), "rrr", rrr_base, min = 0, max = 1),
    scenario_engagement_year1 = as_number(
      pick("engagement_year1"), "engagement_year1", engagement_year_1, min = 0, max = 1
    ),
    scenario_engagement_followup = as_number(
      pick("engagement_followup"), "engagement_followup",
      engagement_years_2_to_10, min = 0, max = 1
    ),
    scenario_utility_no_event = as_number(
      pick("utility_no_event"), "utility_no_event", utility_no_event, min = 0, max = 1
    ),
    scenario_utility_post_mi = as_number(
      pick("utility_post_mi"), "utility_post_mi", utility_post_mi, min = 0, max = 1
    ),
    scenario_utility_post_stroke = as_number(
      pick("utility_post_stroke"), "utility_post_stroke",
      utility_post_stroke, min = 0, max = 1
    ),
    scenario_cost_post_mi_year1 = as_number(
      pick("cost_post_mi_year1"), "cost_post_mi_year1", cost_post_mi_year1, min = 0
    ),
    scenario_cost_post_mi_followup = as_number(
      pick("cost_post_mi_followup"), "cost_post_mi_followup",
      cost_post_mi_followup, min = 0
    ),
    scenario_cost_post_stroke_year1 = as_number(
      pick("cost_post_stroke_year1"), "cost_post_stroke_year1",
      cost_post_stroke_year1, min = 0
    ),
    scenario_cost_post_stroke_followup = as_number(
      pick("cost_post_stroke_followup"), "cost_post_stroke_followup",
      cost_post_stroke_followup, min = 0
    ),
    scenario_discount_rate_cost = as_number(
      pick("discount_rate_cost"), "discount_rate_cost", discount_rate_cost, min = 0, max = 1
    ),
    scenario_discount_rate_effect = as_number(
      pick("discount_rate_effect"), "discount_rate_effect",
      discount_rate_effect, min = 0, max = 1
    ),
    scenario_cycles = as.integer(as_number(
      pick("cycles"), "cycles", cycles, min = 1, max = 100
    ))
  )
}

# Cost and QALY decomposition of one model result, with the same reconciliation
# the Shiny app and run_psa_eqalb() enforce: the parts must sum to the totals.
decompose <- function(components) {
  cost <- list(
    intervention = components[["cost_intervention"]],
    implementation = components[["cost_implementation"]],
    savings = components[["cost_savings"]],
    no_event = components[["cost_no_event"]],
    post_mi = components[["cost_post_mi"]],
    post_stroke = components[["cost_post_stroke"]]
  )
  cost$total <- cost$intervention + cost$implementation + cost$no_event +
    cost$post_mi + cost$post_stroke - cost$savings

  qaly <- list(
    no_event = components[["qaly_no_event"]],
    post_mi = components[["qaly_post_mi"]],
    post_stroke = components[["qaly_post_stroke"]]
  )
  qaly$total <- qaly$no_event + qaly$post_mi + qaly$post_stroke

  list(cost = cost, qaly = qaly)
}

model_results_from_body <- function(body) {
  results <- body[["results"]]
  if (is.null(results) || !is.data.frame(results) || nrow(results) == 0L) {
    stop(
      "The request body must contain the `results` data frame of a completed PSA.",
      call. = FALSE
    )
  }
  required <- c("incremental_cost", "incremental_qalys")
  missing <- required[!required %in% names(results)]
  if (length(missing) > 0L) {
    stop(
      "The PSA results are missing required column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  results
}

# --- API metadata ------------------------------------------------------------

# UI contract for the parameter form. Defaults come from the model constants in
# eqalb_markov.R so the client can never drift from the R base case.
# The interface-copy keys the browser interface uses, and which explanation each
# model parameter shows. The text itself is CC_INFO_TEXT from eqalb_ui_copy.R —
# the same dictionary the Shiny app reads — so the browser interface cannot show
# different wording from Shiny. The tutorial and Part 2 entries in that dictionary
# belong to the Shiny guided tutorial, which has no browser equivalent, and
# `willingness_to_pay` describes the Shiny OWSA threshold control, which the
# browser OWSA tab does not have; none of those is published. The one tutorial
# key that is published is `tutorial_interop_definition`: its sentence is the
# only definition of interoperability that exists in R, and the readiness tab
# shows it on the interoperability control rather than restating it.
COLUMN_INFO_KEYS <- c(
  "intervention_price", "intervention_cost", "healthcare_savings",
  "relative_risk_reduction", "year1_engagement", "followup_engagement",
  "utility", "population_size", "uptake", "review_minutes", "reference_wtp",
  "psa_simulations", "random_seed", "evpi", "evppi", "psa_mean_cost",
  "psa_mean_qalys", "tutorial_interop_definition"
)

# A missing entry would silently drop help text from the interface, so the
# endpoint fails loudly instead of shipping an empty explanation.
info_text <- function(key) {
  text <- CC_INFO_TEXT[[key]]
  if (is.null(text) || !nzchar(text)) {
    stop("No CC_INFO_TEXT entry for '", key, "'.", call. = FALSE)
  }
  text
}

column_info <- function() {
  setNames(lapply(COLUMN_INFO_KEYS, info_text), COLUMN_INFO_KEYS)
}

# Which model parameter shows which explanation. The event costs, the discount
# rates and the time horizon have no mapped key and therefore no control.
PARAMETER_INFO_KEYS <- c(
  intervention_price = "intervention_price",
  implementation_cost = "intervention_cost",
  healthcare_savings = "healthcare_savings",
  rrr = "relative_risk_reduction",
  engagement_year1 = "year1_engagement",
  engagement_followup = "followup_engagement",
  utility_no_event = "utility",
  utility_post_mi = "utility",
  utility_post_stroke = "utility"
)

# "" means "this input has no information control". An empty string is used
# rather than NA so the value is the same string in every serialiser (jsonlite
# writes NA as either null or "NA" depending on options).
info_for <- function(keys, id) {
  if (length(id) != 1L || !(id %in% names(keys))) return("")
  info_text(keys[[id]])
}

# One row per model input, with the label, group, unit, range and step the
# browser form renders. `info` carries the explanation or "".
parameter_specs <- function() {
  specs <- data.frame(
    id = c(
      "intervention_price", "implementation_cost", "healthcare_savings",
      "rrr", "engagement_year1", "engagement_followup",
      "utility_no_event", "utility_post_mi", "utility_post_stroke",
      "cost_post_mi_year1", "cost_post_mi_followup",
      "cost_post_stroke_year1", "cost_post_stroke_followup",
      "discount_rate_cost", "discount_rate_effect", "cycles"
    ),
    label = c(
      "Annual intervention price", "Implementation cost (one-off)",
      "Annual healthcare-use savings",
      "Relative risk reduction among engaged users",
      "Year-1 engagement", "Follow-up engagement (years 2-10)",
      "Utility: no prior cardiovascular event", "Utility: post-MI",
      "Utility: post-stroke",
      "Cost: post-MI, year 1", "Cost: post-MI, follow-up",
      "Cost: post-stroke, year 1", "Cost: post-stroke, follow-up",
      "Cost discount rate", "Effect discount rate", "Time horizon"
    ),
    group = c(
      "Intervention", "Intervention", "Intervention",
      "Clinical", "Clinical", "Clinical",
      "Utilities", "Utilities", "Utilities",
      "Event costs", "Event costs", "Event costs", "Event costs",
      "Discounting", "Discounting", "Time horizon"
    ),
    unit = c(
      "EUR per active user per year", "EUR per new user",
      "EUR per active user per year",
      "percent", "percent", "percent",
      "utility (0-1)", "utility (0-1)", "utility (0-1)",
      "EUR per person", "EUR per person", "EUR per person", "EUR per person",
      "percent", "percent", "years"
    ),
    default = c(
      intervention_price_annual, implementation_cost, healthcare_use_savings_annual,
      rrr_base, engagement_year_1, engagement_years_2_to_10,
      utility_no_event, utility_post_mi, utility_post_stroke,
      cost_post_mi_year1, cost_post_mi_followup,
      cost_post_stroke_year1, cost_post_stroke_followup,
      discount_rate_cost, discount_rate_effect, cycles
    ),
    min = c(
      0, 0, 0,
      0, 0, 0,
      0, 0, 0,
      0, 0, 0, 0,
      0, 0, 1
    ),
    max = c(
      2000, 500, 500,
      0.30, 1, 1,
      1, 1, 1,
      50000, 50000, 50000, 50000,
      0.10, 0.10, 40
    ),
    step = c(
      10, 5, 5,
      0.01, 0.01, 0.01,
      0.01, 0.01, 0.01,
      100, 100, 100, 100,
      0.005, 0.005, 1
    ),
    percent = c(
      FALSE, FALSE, FALSE,
      TRUE, TRUE, TRUE,
      FALSE, FALSE, FALSE,
      FALSE, FALSE, FALSE, FALSE,
      TRUE, TRUE, FALSE
    ),
    stringsAsFactors = FALSE
  )
  specs$info <- vapply(
    specs$id, function(parameter_id) info_for(PARAMETER_INFO_KEYS, parameter_id),
    character(1),
    USE.NAMES = FALSE
  )
  specs
}

# Simulation defaults and bounds, matching the Shiny PSA controls exactly
# (app.R: psa_n_sim 1000, min 100, max 10000, step 100; psa_seed 12345, min 1).
# The bounds are published so the browser form renders the same range the endpoint
# enforces instead of repeating the numbers in TypeScript.
simulation_defaults <- function() {
  list(
    psa_n_sim = 1000L,
    psa_seed = 12345L,
    psa_n_sim_min = 100L,
    psa_n_sim_max = 10000L,
    psa_n_sim_step = 100L,
    psa_seed_min = 1L,
    reference_wtp = 100000,
    km_n_per_arm = 1000L,
    km_followup_years = as.integer(cycles),
    km_seed = 20261004L
  )
}

# Readiness parameter contract for POST /api/readiness. The defaults and ranges
# are those of the full-analysis DHT Readiness & Implementation tab of the Shiny
# app, so the client cannot drift from them. Engagement is expressed in percent
# because that is the unit calculate_readiness() expects; its default is the
# shared Global Settings engagement slider, which is the model constant in
# percent.
readiness_parameter_specs <- function() {
  specs <- data.frame(
    id = c(
      "target_population", "digital_access", "digital_suitability",
      "readiness_year1_engagement", "readiness_followup_engagement",
      "review_minutes", "supported_languages", "accessibility_features"
    ),
    label = c(
      "Clinical target population", "Smartphone/internet access",
      "Digitally suitable population", "Year-1 engagement",
      "Follow-up engagement (years 2-10)",
      "Clinician-review minutes per patient per month",
      "Number of supported languages", "Accessibility features available"
    ),
    group = c(
      "Population and access", "Population and access", "Population and access",
      "Engagement", "Engagement", "Workflow burden", "Language access",
      "Accessibility"
    ),
    unit = c(
      "people", "percent", "percent", "percent", "percent",
      "minutes per patient per month", "languages", "boolean"
    ),
    type = c(
      "number", "number", "number", "number", "number", "number", "number",
      "boolean"
    ),
    default = c(
      100000, 85, 75, 100 * engagement_year_1, 100 * engagement_years_2_to_10,
      10, 1, 1
    ),
    min = c(0, 0, 0, 0, 0, 0, 1, 0),
    max = c(NA, 100, 100, 100, 100, NA, NA, 1),
    step = c(1000, 1, 1, 1, 1, 1, 1, 1),
    percent = c(FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  # Only the clinician-review input has an explanation in CC_INFO_TEXT (Shiny
  # shows it as "more review minutes means more total clinician hours"); the other
  # readiness controls have none, so they carry "".
  specs$info <- vapply(
    specs$id,
    function(id) if (identical(id, "review_minutes")) info_text("review_minutes") else "",
    character(1),
    USE.NAMES = FALSE
  )
  specs
}

# The select-style readiness inputs. `levels` come from eqalb_readiness.R and the
# defaults are the values the Shiny readiness sidebar preselects, so both the
# defaults response and the endpoint read them from one place.
readiness_choices <- function() {
  list(
    interoperability = list(
      label = "Interoperability maturity",
      default = "PDF/manual export",
      levels = DHT_INTEROPERABILITY_LEVELS,
      # The definition that already exists in CC_INFO_TEXT for the guided
      # tutorial. Published here so the browser interface shows R's own sentence
      # instead of writing one of its own.
      info = info_text("tutorial_interop_definition")
    ),
    algorithm_governance = list(
      label = "Algorithm change approach",
      default = "Periodic controlled updates",
      levels = DHT_ALGORITHM_APPROACHES,
      # No explanation exists in R for this control, and none is invented: the
      # four approach names carry their own meaning, as they do in Shiny.
      info = ""
    )
  )
}

readiness_defaults <- function() {
  list(
    parameters = readiness_parameter_specs(),
    choices = readiness_choices()
  )
}

# The ten readiness inputs in the units calculate_readiness() expects, with the
# values the Shiny full-analysis tab preselects. Both /api/readiness and the
# readiness block of /api/hta-summary build their arguments here, so the two
# endpoints cannot drift and no readiness rule is restated anywhere else.
readiness_args <- function(source = list()) {
  choices <- readiness_choices()
  list(
    target_population = body_number(
      source, "target_population", 100000, min = 0
    ),
    digital_access = body_number(source, "digital_access", 85, min = 0, max = 100),
    digital_suitability = body_number(
      source, "digital_suitability", 75, min = 0, max = 100
    ),
    readiness_year1_engagement = body_number(
      source, "readiness_year1_engagement", 100 * engagement_year_1,
      min = 0, max = 100
    ),
    readiness_followup_engagement = body_number(
      source, "readiness_followup_engagement", 100 * engagement_years_2_to_10,
      min = 0, max = 100
    ),
    review_minutes = body_number(source, "review_minutes", 10, min = 0),
    supported_languages = body_number(
      source, "supported_languages", 1, min = 1
    ),
    accessibility_features = body_flag(source, "accessibility_features", TRUE),
    interoperability = body_choice(
      source, "interoperability",
      choices$interoperability$levels, choices$interoperability$default
    ),
    algorithm_governance = body_choice(
      source, "algorithm_governance",
      choices$algorithm_governance$levels, choices$algorithm_governance$default
    )
  )
}

# --- Routes ------------------------------------------------------------------

#* @apiTitle eQalb illustrative HTA model API
#* @apiDescription HTTP wrapper around the eQalb R model modules. All clinical
#*   and economic values are simulated illustrative data, not clinical evidence.

#* Enable browser access from the Vite dev server and file previews.
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (identical(toupper(req$REQUEST_METHOD), "OPTIONS")) {
    res$status <- 200L
    return(list())
  }
  plumber::forward()
}

#* Liveness and model-module status.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @get /api/health
function() {
  loaded <- vapply(
    MODEL_FUNCTIONS,
    function(name) exists(name, mode = "function", inherits = TRUE),
    logical(1)
  )
  list(
    status = "ok",
    service = "eQalb illustrative HTA model API",
    root = API_ROOT,
    model_modules = MODEL_MODULES,
    model_functions = as.list(loaded),
    model_ready = all(loaded),
    notice = simulated_notice()
  )
}

#* Base-case parameter values, the UI parameter contract, the one-way
#* sensitivity-analysis ranges for that base case, simulation defaults and the
#* readiness contract (parameters, interoperability levels and
#* algorithm-governance approaches).
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @get /api/defaults
function() {
  list(
    parameters = parameter_specs(),
    # The one-way ranges for the model's own base-case scenario, from the canonical
    # policy in eqalb_owsa.R. A caller with its own scenario asks
    # POST /api/owsa-defaults instead, which derives the same ranges from it.
    owsa_parameters = eqalb_owsa_range_bounds(eqalb_owsa_base_args()),
    owsa_bounds_note = EQALB_OWSA_RANGE_NOTE,
    rrr_sensitivity_range = list(low = rrr_low, high = rrr_high),
    simulation_defaults = simulation_defaults(),
    readiness = readiness_defaults(),
    # The analysis explanations from CC_INFO_TEXT, keyed exactly as the Shiny
    # dictionary keys them, so a client can read one by key without a mapping
    # table of its own. Each parameters[] and readiness.parameters[] row also
    # carries its own `info` string.
    info_text = column_info(),
    # Shiny's one-way sensitivity-analysis tab copy that the browser interface
      # needs before any run: the paragraph above the summary and the sentence the
      # summary shows until the analysis has been run. The narrative itself comes
      # back with POST /api/owsa.
      owsa_summary_note = OWSA_SUMMARY_NOTE,
      owsa_prerun_note = OWSA_PRERUN_NOTE,
    # The method note behind each module's "How this is calculated" control: what
    # the module runs, what it reads and what it assumes. Presentation only, keyed
    # by the module id the interface already uses for its own tab. A module that
    # published nothing here shows no control rather than a guessed note.
    module_methods = MODULE_METHOD_NOTES,
    model = list(
      cycles = as.integer(cycles),
      states = c("NoEvent", "PostMI", "PostStroke", "Death"),
      strategies = c("UsualCare", "eQalb"),
      perspective = "German payer, 2025 euros, per person"
    ),
    notice = simulated_notice()
  )
}

#* Deterministic base case: incremental cost, incremental QALYs, ICER and the
#* reconciled cost/QALY decomposition.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/base-case
function(req) {
  body <- parse_body(req)
  args <- scenario_args(body)
  result <- do.call(run_eqalb_model, args)
  wtp <- query_number(req, "wtp", 100000, min = 0)

  parts <- decompose(result$components)
  if (!isTRUE(all.equal(parts$cost$total, result$incremental_cost, tolerance = 1e-8)) ||
    !isTRUE(all.equal(parts$qaly$total, result$incremental_qalys, tolerance = 1e-8))) {
    stop(
      "The component decomposition does not reconcile with the incremental totals.",
      call. = FALSE
    )
  }

  incremental_cost <- scalar_out(result$incremental_cost)
  incremental_qalys <- scalar_out(result$incremental_qalys)
  nmb <- scalar_out(incremental_qalys * wtp - incremental_cost)
  list(
    incremental_cost = incremental_cost,
    incremental_qalys = incremental_qalys,
    icer = scalar_out(result$icer),
    net_monetary_benefit = nmb,
    wtp = wtp,
    cost_effective = if (is.na(nmb)) NA else nmb >= 0,
    cost_components = lapply(parts$cost, scalar_out),
    qaly_components = lapply(parts$qaly, scalar_out),
    inputs = lapply(args, scalar_out),
    notice = simulated_notice()
  )
}

#* Probabilistic sensitivity analysis, CEAC and the simulation cloud.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/psa
function(req) {
  body <- parse_body(req)
  args <- scenario_args(body)
  # Bounds are Shiny's own PSA control limits (app.R), and the defaults are
  # /api/defaults' simulation_defaults, so the form and the endpoint agree.
  defaults <- simulation_defaults()
  n_sim <- query_number(
    req, "n_sim", defaults$psa_n_sim,
    min = defaults$psa_n_sim_min, max = defaults$psa_n_sim_max
  )
  seed <- query_number(
    req, "seed", defaults$psa_seed,
    min = defaults$psa_seed_min, max = .Machine$integer.max
  )
  wtp <- query_number(req, "wtp", 100000, min = 0)
  max_wtp <- query_number(req, "max_wtp", max(150000, wtp * 2), min = 1000)

  psa <- run_psa_eqalb(
    n_sim = as.integer(n_sim),
    seed = as.integer(seed),
    max_wtp = max_wtp,
    wtp_thresholds = unique(c(50000, wtp, 150000)),
    intervention_price = args$scenario_intervention_price,
    implementation = args$scenario_implementation_cost,
    savings = args$scenario_healthcare_savings,
    rrr = args$scenario_rrr,
    engagement_year1 = args$scenario_engagement_year1,
    engagement_followup = args$scenario_engagement_followup,
    no_event_utility = args$scenario_utility_no_event,
    post_mi_utility = args$scenario_utility_post_mi,
    post_stroke_utility = args$scenario_utility_post_stroke
  )

  mean_cost <- scalar_out(psa$mean_incremental_cost)
  mean_qaly <- scalar_out(psa$mean_incremental_qalys)
  list(
    n_requested = psa$n_requested,
    n_successful = psa$n_successful,
    n_failed = psa$n_failed,
    seed = as.integer(seed),
    wtp = wtp,
    max_wtp = max_wtp,
    mean_incremental_cost = mean_cost,
    mean_incremental_qalys = mean_qaly,
    mean_net_monetary_benefit = scalar_out(mean_qaly * wtp - mean_cost),
    median_icer = scalar_out(psa$median_icer),
    mean_components = lapply(as.list(psa$mean_components), scalar_out),
    probability_cost_effective = lapply(as.list(psa$probability_cost_effective), scalar_out),
    wtp_thresholds = vector_out(psa$wtp_thresholds),
    ceac = psa$ceac,
    cloud = psa$results[, c("simulation", "incremental_cost", "incremental_qalys", "icer")],
    results = psa$results,
    notice = simulated_notice()
  )
}

#* One-way deterministic sensitivity analysis (tornado table plus base case).
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/owsa
function(req) {
  body <- parse_body(req)
  args <- scenario_args(body)
  wtp <- query_number(req, "wtp", 100000, min = 0)

  outcome <- body[["outcome"]]
  if (is.null(outcome) || length(outcome) != 1L || is.na(outcome)) {
    outcome <- req$argsQuery[["outcome"]]
  }
  if (is.null(outcome) || length(outcome) != 1L || is.na(outcome)) {
    outcome <- "inmb"
  }
  outcome <- as.character(outcome)
  if (!outcome %in% names(eqalb_owsa_outcome_labels)) {
    stop(
      "'outcome' must be one of: ",
      paste(names(eqalb_owsa_outcome_labels), collapse = ", "),
      call. = FALSE
    )
  }

  # The ranges in force: R's canonical policy derives one for every parameter from
  # the scenario being analysed, and any range the caller supplied replaces the row
  # it names. A range R cannot use is an error here, reported with R's own sentence;
  # /api/owsa-defaults reports the same sentence without failing, so an interface
  # can show it while the caller is still choosing values.
  bounds <- eqalb_owsa_range_bounds(args, body[["bounds"]])
  unusable <- bounds[bounds$range_status == "invalid", , drop = FALSE]
  if (nrow(unusable) > 0L) {
    stop(unusable$range_note[[1]], call. = FALSE)
  }

  result <- run_eqalb_owsa(
    base_args = args,
    bounds = bounds,
    wtp = wtp,
    outcome = outcome
  )

  table <- result$table
  numeric_columns <- names(table)[vapply(table, is.numeric, logical(1))]
  table[numeric_columns] <- lapply(table[numeric_columns], vector_out)

  list(
    outcome = result$outcome,
    outcome_label = result$outcome_label,
    wtp = wtp,
    base_outcome = scalar_out(result$base_outcome),
    base_incremental_cost = scalar_out(result$base$incremental_cost),
    base_incremental_qalys = scalar_out(result$base$incremental_qalys),
    base_incremental_nmb = scalar_out(result$base$inmb),
    table = table,
    bounds = bounds,
    bounds_note = EQALB_OWSA_RANGE_NOTE,
    # The Shiny tab's plain-language narrative, built by the same R function it
    # calls, plus the paragraph the tab shows above it. No sentence is composed
    # here.
    summary = summarize_eqalb_owsa(eqalb_owsa_scenario_rows(result)),
    summary_note = OWSA_SUMMARY_NOTE,
    notice = simulated_notice()
  )
}

#* The one-way range policy applied to one scenario, without running the analysis:
#* R's derived lower and upper value for every parameter, with any supplied range
#* applied and judged. An editor uses it to show the ranges that are in force for
#* the assumptions currently in the form.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/owsa-defaults
function(req) {
  body <- parse_body(req)
  args <- scenario_args(body)
  list(
    bounds = eqalb_owsa_range_bounds(args, body[["bounds"]]),
    bounds_note = EQALB_OWSA_RANGE_NOTE,
    notice = simulated_notice()
  )
}

#* Budget-impact analysis over the requested horizon.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/budget-impact
function(req) {
  body <- parse_body(req)
  args <- scenario_args(body)

  population <- body_number(body, "population", 70000, min = 0)
  year1_uptake_pct <- body_number(body, "year1_uptake_pct", 10, min = 0, max = 100)
  annual_uptake_increase_pp <- body_number(
    body, "annual_uptake_increase_pp", 5, min = 0, max = 100
  )
  horizon_years <- body_number(body, "horizon_years", 5, min = 1, max = 40)
  avoided_event_savings <- body_number(
    body, "avoided_event_savings_per_active_user", 0, min = 0
  )
  followup_engagement_pct <- body_number(
    body, "followup_engagement_pct",
    args$scenario_engagement_followup * 100, min = 0, max = 100
  )

  table <- calculate_budget_impact(
    population = population,
    year1_uptake_pct = year1_uptake_pct,
    annual_uptake_increase_pp = annual_uptake_increase_pp,
    horizon_years = horizon_years,
    intervention_price = args$scenario_intervention_price,
    implementation_cost_per_new_user = args$scenario_implementation_cost,
    healthcare_savings_per_active_user = args$scenario_healthcare_savings,
    avoided_event_savings_per_active_user = avoided_event_savings,
    followup_engagement_pct = followup_engagement_pct
  )
  numeric_columns <- names(table)[vapply(table, is.numeric, logical(1))]
  table[numeric_columns] <- lapply(table[numeric_columns], vector_out)

  list(
    horizon_years = as.integer(horizon_years),
    population = population,
    table = table,
    total_intervention_cost = scalar_out(sum(table$gross_intervention_cost)),
    total_implementation_cost = scalar_out(sum(table$implementation_cost)),
    total_healthcare_savings = scalar_out(sum(table$healthcare_savings)),
    total_avoided_event_savings = scalar_out(sum(table$avoided_event_savings)),
    cumulative_net_budget_impact = scalar_out(
      table$cumulative_budget_impact[nrow(table)]
    ),
    inputs = list(
      intervention_price = args$scenario_intervention_price,
      implementation_cost_per_new_user = args$scenario_implementation_cost,
      healthcare_savings_per_active_user = args$scenario_healthcare_savings,
      avoided_event_savings_per_active_user = avoided_event_savings,
      followup_engagement_pct = followup_engagement_pct
    ),
    notice = simulated_notice()
  )
}

#* Value of information (EVPI and EVPPI) from PSA draws supplied by the client,
#* so the expensive PSA is not rerun.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/value-of-information
function(req) {
  body <- parse_body(req)
  results <- model_results_from_body(body)
  wtp <- query_number(req, "wtp", 100000, min = 0)

  evpi <- voi_evpi(results, wtp = wtp)
  evppi <- voi_evppi(results, wtp = wtp)

  list(
    wtp = wtp,
    n = evpi$n,
    evpi = list(
      mean_incremental_cost = scalar_out(evpi$mean_incremental_cost),
      mean_incremental_qalys = scalar_out(evpi$mean_incremental_qalys),
      mean_nmb = scalar_out(evpi$mean_nmb),
      expected_nmb_perfect = scalar_out(evpi$expected_nmb_perfect),
      expected_nmb_current = scalar_out(evpi$expected_nmb_current),
      evpi = scalar_out(evpi$evpi)
    ),
    evppi = evppi,
    notice = simulated_notice()
  )
}

#* Simulated illustrative Kaplan-Meier survival analysis.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/survival
function(req) {
  body <- parse_body(req)
  args <- scenario_args(body)

  n_per_arm <- body_number(body, "n_per_arm", 1000, min = 10, max = 20000)
  followup_years <- body_number(
    body, "followup_years", as.integer(cycles), min = 1, max = 40
  )
  seed <- body_number(body, "seed", 20261004, min = 0, max = .Machine$integer.max)
  p_mi <- body_number(body, "p_mi", p_mi_usual_care, min = 0, max = 1)
  p_stroke <- body_number(body, "p_stroke", p_stroke_usual_care, min = 0, max = 1)
  p_other_death <- body_number(body, "p_other_death", p_other_death, min = 0, max = 1)

  data <- simulate_eqalb_survival(
    n_per_arm = as.integer(n_per_arm),
    followup_years = as.integer(followup_years),
    seed = as.integer(seed),
    rrr = args$scenario_rrr,
    engagement_year1 = args$scenario_engagement_year1,
    engagement_followup = args$scenario_engagement_followup,
    p_mi = p_mi,
    p_stroke = p_stroke,
    p_other_death = p_other_death
  )

  expected <- expected_eqalb_events(
    n_per_arm = as.integer(n_per_arm),
    followup_years = as.integer(followup_years),
    rrr = args$scenario_rrr,
    engagement_year1 = args$scenario_engagement_year1,
    engagement_followup = args$scenario_engagement_followup,
    p_mi = p_mi,
    p_stroke = p_stroke,
    p_other_death = p_other_death
  )

  # Step coordinates from the same estimator summarize_eqalb_survival() uses,
  # so the curve and the summary table cannot disagree.
  groups <- c("Usual care", "eQalb plus usual care")
  steps <- do.call(rbind, lapply(groups, function(group) {
    arm <- data[data$treatment == group, , drop = FALSE]
    fit <- survival::survfit(survival::Surv(time_years, event_status) ~ 1, data = arm)
    data.frame(
      treatment = group,
      time_years = c(0, fit$time),
      survival = c(1, fit$surv),
      lower = c(1, fit$lower),
      upper = c(1, fit$upper),
      n_risk = c(nrow(arm), fit$n.risk),
      n_event = c(0, fit$n.event),
      stringsAsFactors = FALSE
    )
  }))
  numeric_columns <- names(steps)[vapply(steps, is.numeric, logical(1))]
  steps[numeric_columns] <- lapply(steps[numeric_columns], vector_out)

  years <- 0:as.integer(followup_years)
  risk_table <- do.call(rbind, lapply(groups, function(group) {
    arm_steps <- steps[steps$treatment == group, , drop = FALSE]
    data.frame(
      treatment = group,
      year = years,
      at_risk = vector_out(vapply(years, function(year) {
        idx <- which(arm_steps$time_years <= year)
        if (length(idx) == 0L) 0 else arm_steps$n_risk[max(idx)]
      }, numeric(1))),
      stringsAsFactors = FALSE
    )
  }))

  summary_table <- summarize_eqalb_survival(data, followup_years)
  numeric_columns <- names(summary_table)[vapply(summary_table, is.numeric, logical(1))]
  summary_table[numeric_columns] <- lapply(summary_table[numeric_columns], vector_out)

  diagnostics <- diagnose_eqalb_survival(data, followup_years)
  numeric_columns <- names(diagnostics)[vapply(diagnostics, is.numeric, logical(1))]
  diagnostics[numeric_columns] <- lapply(diagnostics[numeric_columns], vector_out)

  arm_contrast <- assess_eqalb_arm_contrast(data, expected_events = expected)
  checks <- arm_contrast$checks
  numeric_columns <- names(checks)[vapply(checks, is.numeric, logical(1))]
  checks[numeric_columns] <- lapply(checks[numeric_columns], vector_out)

  # The traffic-light interpretation is the function the Shiny Kaplan-Meier tab
  # calls, sourced from eqalb_km_interpretation.R. It reads the same simulated
  # statistics this response already carries, so the curve, the tables and the
  # interpretation cannot describe different runs, and no status is derived
  # outside R. km_number() / km_p_value() are R's own formatters, used here for
  # the same values the Shiny panel prints.
  interpretation <- assess_km_interpretation(
    diagnostics$summary,
    logrank_p = arm_contrast$logrank_p,
    hazard_ratio = arm_contrast$hazard_ratio_cc_vs_uc,
    competing_death_p = arm_contrast$competing_death_p
  )

  list(
    n_per_arm = as.integer(n_per_arm),
    followup_years = as.integer(followup_years),
    seed = as.integer(seed),
    rrr = args$scenario_rrr,
    engagement_year1 = args$scenario_engagement_year1,
    engagement_followup = args$scenario_engagement_followup,
    steps = steps,
    risk_table = risk_table,
    summary = summary_table,
    diagnostics = diagnostics,
    expected_events = lapply(as.list(expected), scalar_out),
    arm_contrast = list(
      checks = checks,
      logrank_p = scalar_out(arm_contrast$logrank_p),
      hazard_ratio_cc_vs_uc = scalar_out(arm_contrast$hazard_ratio_cc_vs_uc),
      verdict = trimws(arm_contrast$verdict)
    ),
    interpretation = list(
      overall_status = interpretation$overall_status,
      domains = interpretation$domains,
      counts = lapply(as.list(interpretation$counts), scalar_out),
      interpretation = interpretation$interpretation,
      rules = interpretation$rules,
      display = list(
        hazard_ratio = km_number(interpretation$counts$hazard_ratio),
        logrank_p = km_p_value(interpretation$counts$logrank_p),
        competing_death_p = km_p_value(interpretation$counts$competing_death_p)
      )
    ),
    # The Shiny Kaplan-Meier tab's own log-rank line, word for word: the
    # p-value is descriptive and comes from simulated data, and the
    # simulated-data notice is repeated with it.
    logrank_note = paste0(
      "Descriptive log-rank p-value (simulated data only): ",
      km_p_value(interpretation$counts$logrank_p), ". ", simulated_notice()
    ),
    event_note = get0("SIMULATED_EVENT_NOTE", envir = globalenv(), ifnotfound = ""),
    notice = simulated_notice()
  )
}

#* Illustrative DHT readiness and implementation assessment.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/readiness
function(req) {
  body <- parse_body(req)

  # Every value is handed to calculate_readiness() in the units it already
  # expects: the two access shares and the two engagement values are percentages
  # (as in the Shiny sliders), review minutes are minutes per patient per month,
  # and the two select inputs are matched against the readiness module's levels.
  result <- do.call(calculate_readiness, readiness_args(body))

  # The calculation object is returned as produced: the five figures, the three
  # character tables, the status counts and the interpretation. Only the figures
  # pass through scalar_out(), so a non-finite value becomes JSON null rather
  # than "Infinity"/"NaN" (engagement_retention_pct is NA when year-1 engagement
  # is 0, which the Shiny app reports as "NA (year-1 engagement is 0)").
  list(
    eligible_population = scalar_out(result$eligible_population),
    active_users_year1 = scalar_out(result$active_users_year1),
    active_users_followup = scalar_out(result$active_users_followup),
    engagement_retention_pct = scalar_out(result$engagement_retention_pct),
    annual_clinician_hours = scalar_out(result$annual_clinician_hours),
    numbers = result$numbers,
    domains = result$domains,
    cards = result$cards,
    counts = as.list(result$counts),
    interpretation = result$interpretation,
    notice = simulated_notice()
  )
}

#* HTA decision summary and dynamic evidence priorities, built from analyses the
#* caller has already run. Every completed-analysis value is optional: an
#* omitted value means that analysis has not been run, and the R functions then
#* report their own "Not available" / "Not yet available" wording instead of a
#* guessed result.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/hta-summary
function(req) {
  body <- parse_body(req)

  # Reference willingness-to-pay threshold: accepted in the body or as ?wtp=,
  # like /api/owsa.
  wtp <- body[["wtp"]]
  if (is.null(wtp) || length(wtp) != 1L || is.na(wtp)) {
    wtp <- req$argsQuery[["wtp"]]
  }
  reference_wtp <- as_number(wtp, "wtp", 100000, min = 0)

  # Completed-analysis values, in the units the R functions read. Absent stays
  # NA_real_, so a missing analysis never becomes a number the caller did not
  # measure.
  icer <- body_optional_number(body, "icer")
  # The economic rule reads the two differences rather than the ICER, so both are
  # accepted: a negative ICER cannot say whether eQalb is dominant or dominated,
  # while the incremental cost and health can.
  incremental_cost <- body_optional_number(body, "incremental_cost")
  incremental_qalys <- body_optional_number(body, "incremental_qalys")
  probability_cost_effective <- body_optional_number(
    body, "probability_cost_effective", min = 0, max = 1
  )
  mean_incremental_nmb <- body_optional_number(body, "mean_incremental_nmb")
  evpi <- body_optional_number(body, "evpi")
  highest_evppi <- body_optional_number(body, "highest_evppi")
  cumulative_budget_impact <- body_optional_number(
    body, "cumulative_budget_impact"
  )
  bia_intervention_cost <- body_optional_number(body, "bia_intervention_cost")
  bia_implementation_cost <- body_optional_number(body, "bia_implementation_cost")
  bia_healthcare_savings <- body_optional_number(body, "bia_healthcare_savings")

  # EVPPI rows as returned by /api/value-of-information (parameter, evppi). EVPPI
  # is supporting signal only, so an unavailable table is simply omitted.
  evppi_table <- body[["evppi_table"]]
  if (!is.null(evppi_table)) {
    if (!is.data.frame(evppi_table)) {
      stop(
        "Body 'evppi_table' must be an array of {parameter, evppi} objects.",
        call. = FALSE
      )
    }
    missing <- c("parameter", "evppi")[
      !c("parameter", "evppi") %in% names(evppi_table)
    ]
    if (length(missing) > 0L) {
      stop(
        "Body 'evppi_table' must contain parameter and evppi columns. Missing: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
  }

  # Scenario inputs behind the evidence-priority signals, with the model's own
  # base-case constants as defaults (the same helper every other endpoint uses).
  args <- scenario_args(body)

  # Readiness: the caller sends the readiness inputs, the same ones /api/readiness
  # accepts, and the seven domains are derived here by calculate_readiness(). No
  # domain or dashboard status is ever accepted from the client. Omitting the
  # block means readiness has not been assessed, which the R functions report as
  # "Not available".
  supplied <- body[["readiness"]]
  if (!is.null(supplied) && !is.list(supplied)) {
    stop(
      "Body 'readiness' must be a JSON object of readiness inputs.",
      call. = FALSE
    )
  }
  readiness <- readiness_args(if (is.null(supplied)) list() else supplied)
  readiness_domains <- if (is.null(supplied)) {
    NULL
  } else {
    do.call(calculate_readiness, readiness)$domains
  }

  summary_result <- assess_hta_decision_summary(
    icer = icer,
    reference_wtp = reference_wtp,
    probability_cost_effective = probability_cost_effective,
    mean_incremental_nmb = mean_incremental_nmb,
    evpi = evpi,
    highest_evppi = highest_evppi,
    cumulative_budget_impact = cumulative_budget_impact,
    readiness_domains = readiness_domains,
    incremental_cost = incremental_cost,
    incremental_qalys = incremental_qalys
  )

  # The evidence priorities read the dashboard statuses back out of that result,
  # exactly as the Shiny tab does, so every status is derived in one place.
  status_of <- function(domain) {
    hit <- summary_result$domains$Domain == domain
    if (!any(hit)) NA_character_ else summary_result$domains$Status[which(hit)[1]]
  }

  priorities <- build_hta_evidence_priorities(
    icer = icer,
    probability_cost_effective = probability_cost_effective,
    evpi = evpi,
    evppi_table = evppi_table,
    cumulative_budget_impact = cumulative_budget_impact,
    bia_intervention_cost = bia_intervention_cost,
    bia_implementation_cost = bia_implementation_cost,
    bia_healthcare_savings = bia_healthcare_savings,
    annual_price = args$scenario_intervention_price,
    implementation_cost_per_new_user = args$scenario_implementation_cost,
    savings_per_active_user = args$scenario_healthcare_savings,
    rrr = args$scenario_rrr,
    engagement_year1 = args$scenario_engagement_year1,
    engagement_followup = args$scenario_engagement_followup,
    review_minutes = readiness$review_minutes,
    digital_access = readiness$digital_access,
    digital_suitability = readiness$digital_suitability,
    interoperability_maturity = readiness$interoperability,
    readiness_domains = readiness_domains,
    economic_status = status_of("Economic value"),
    uncertainty_status = status_of("Decision uncertainty"),
    budget_status = status_of("Budget impact"),
    evidence_status = status_of("Clinical evidence maturity")
  )

  # Structured availability, so a client can say what is still missing rather
  # than inferring it from absent numbers. Each flag mirrors the check the Shiny
  # tab makes before reading an upstream analysis, and the domain lists are read
  # back from the R summary.
  assessed <- summary_result$domains$Status %in% c("Green", "Amber", "Red")

  # The economic verdict is the sign of the incremental net monetary benefit, so
  # the base case counts as supplied when either its two differences or its ICER
  # arrived. Gating that on the ICER alone misreported the case where there is no
  # ICER to send: an option with no incremental health has no ICER by
  # construction, and a dominant one has a negative ratio that must not be read as
  # a threshold comparison.
  #
  # What the rule cannot do without is the pair of differences, so they are what
  # the missing list names — always, whatever the ICER says. A request that sends
  # only an ICER therefore reports the base case as included and still asks for
  # the two values its verdict actually needs.
  base_case_supplied <- !is.na(icer) ||
    (!is.na(incremental_cost) && !is.na(incremental_qalys))
  missing_base_case_fields <- c(
    if (is.na(incremental_cost)) "incremental_cost",
    if (is.na(incremental_qalys)) "incremental_qalys"
  )

  list(
    wtp = reference_wtp,
    summary = list(
      domains = summary_result$domains,
      overall_status = summary_result$overall_status,
      position = summary_result$position,
      interpretation = summary_result$interpretation
    ),
    evidence_priorities = list(
      table = priorities$table,
      summary = priorities$summary
    ),
    # The rules behind the statuses, from eqalb_ui_copy.R: the popover items the
    # Shiny dashboard shows, the note under its evidence-priority table, and the
    # single-paragraph rule summary that also goes into the exported results
    # package. Copied nowhere else, so the wording cannot drift.
    rules = unname(HTA_RULE_ITEMS),
    evidence_note = HTA_EVIDENCE_NOTE,
    rule_note = HTA_SUMMARY_RULE_NOTE,
    availability = list(
      base_case = base_case_supplied,
      psa = !is.na(probability_cost_effective) && !is.na(evpi),
      value_of_information = !is.na(evpi) || !is.null(evppi_table),
      budget_impact = !is.na(cumulative_budget_impact),
      readiness = !is.null(supplied),
      missing_inputs = c(
        missing_base_case_fields,
        if (is.na(probability_cost_effective)) "probability_cost_effective",
        if (is.na(evpi)) "evpi",
        if (is.na(cumulative_budget_impact)) "cumulative_budget_impact",
        if (is.null(supplied)) "readiness"
      ),
      not_assessable_domains = summary_result$domains$Domain[!assessed],
      assessed_domains = as.integer(sum(assessed))
    ),
    notice = simulated_notice()
  )
}

# --- Value-based price -------------------------------------------------------

# Non-finite numbers become NA (JSON null on the primary service) and data frames
# keep their shape, so a client never receives "Infinity"/"NaN" and the scan
# table stays a table. The module returns the same shape for an unavailable
# value, so this only guards against arithmetic that is not finite.
price_clean <- function(value) {
  if (is.data.frame(value)) {
    numeric_columns <- names(value)[vapply(value, is.numeric, logical(1))]
    value[numeric_columns] <- lapply(value[numeric_columns], vector_out)
    return(value)
  }
  if (is.list(value)) {
    return(lapply(value, price_clean))
  }
  if (is.numeric(value)) {
    return(if (length(value) == 1L) scalar_out(value) else vector_out(value))
  }
  value
}

#* Value-based price: the highest annual intervention price the model supports at
#* the reference willingness-to-pay threshold, the price headroom against the
#* current price, the relative risk reduction the current price would require, and
#* a 3 x 3 scan of the supported price across the model's own relative-risk-
#* reduction and year-1 engagement bounds.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/value-based-price
function(req) {
  body <- parse_body(req)
  args <- scenario_args(body)

  # Reference willingness-to-pay threshold: accepted in the body or as ?wtp=,
  # like /api/hta-summary.
  wtp <- body[["wtp"]]
  if (is.null(wtp) || length(wtp) != 1L || is.na(wtp)) {
    wtp <- req$argsQuery[["wtp"]]
  }
  wtp <- as_number(wtp, "wtp", 100000, min = 0)

  # `current_price` is the annual intervention price the analysis runs at and
  # compares the maximum acceptable price against. It is an alias for the
  # scenario input, applied here rather than derived later, so the model, the
  # price solve and the headroom all describe one price.
  warnings <- character(0)
  supplied_price <- body_optional_number(
    body, "current_price", min = 0, max = 1e6
  )
  if (!is.na(supplied_price)) {
    body_price <- body[["intervention_price"]]
    if (!is.null(body_price) && length(body_price) == 1L) {
      numeric_body_price <- suppressWarnings(as.numeric(body_price))
      if (!is.na(numeric_body_price) &&
        !isTRUE(all.equal(numeric_body_price, supplied_price))) {
        warnings <- c(
          warnings,
          "'current_price' overrides 'intervention_price' for this analysis."
        )
      }
    }
    args$scenario_intervention_price <- supplied_price
  }

  result <- calculate_value_based_price(
    base_args = args,
    wtp = wtp,
    current_price = args$scenario_intervention_price
  )

  # Structured availability, so a client can say which values could be identified
  # and why an unavailable one is unavailable. `missing_inputs` lists request
  # fields the analysis needs that were not supplied and have no model default;
  # over HTTP every model input has one, so it is empty for every request.
  availability <- result$availability
  availability$missing_inputs <- as.list(availability$missing_inputs)

  list(
    analysis = result$analysis,
    method = result$method,
    method_note = result$method_note,
    wtp = wtp,
    current_price = scalar_out(result$current_price),
    status = result$status,
    scenario = price_clean(result$scenario),
    headline = price_clean(result$headline),
    required_effect = price_clean(result$required_effect),
    grid = price_clean(result$grid),
    availability = availability,
    interpretation = result$interpretation,
    limitation = result$limitation,
    inputs = lapply(args, scalar_out),
    warnings = as.list(warnings),
    notice = simulated_notice()
  )
}

# --- Guided Tutorial Part 1 --------------------------------------------------

#* Guided Tutorial Part 1 contract: the tutorial's own defaults, control
#* metadata (labels, units, ranges, steps), fixed R-owned values including the
#* post-event utilities, instructional strings, step titles and objectives.
#* No model run happens to build it.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @get /api/tutorial
function() {
  eqalb_tutorial_contract()
}

#* Guided Tutorial Part 1 results for all four steps: the base case, its
#* cost-effectiveness presentation data, the budget impact, the readiness
#* assessment, the tutorial decision summary and R's own interpretations. The
#* request carries only the tutorial's own nine controls; every other value is a
#* tutorial-owned default, so the tutorial never reads a full-analysis setting.
#* Deterministic: the same body always returns the same response.
#*
#* The path is flat because plumber cannot hold a route and a nested route that
#* share a prefix: defining /api/tutorial/part1 alongside /api/tutorial rebuilds
#* plumber's route table and drops the sibling routes. The published contract is
#* POST /api/tutorial/part1, which the FastAPI service serves and maps here — see
#* api/api_contract.md.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-part1
function(req) {
  eqalb_tutorial_part1(parse_body(req))
}

#* Guided Tutorial Part 2 contract: the five section names with only the two this
#* slice implements marked available, the R-owned instructional copy, the
#* negotiated-price control metadata, the case-facts table headings and overlay
#* labels, the value-for-money presentation labels, the chart's labels and
#* series colours, and the fixed inputs the later sections will use. No model run
#* and no case draw happens to build it.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @get /api/tutorial-part2
function() {
  eqalb_tutorial_part2_contract()
}

#* Creates or resumes a Guided Tutorial Part 2 case. With no body (or no
#* 'case_id') R draws a case for a new session and returns its opaque handle;
#* with the handle it returns that same case unchanged, so a client resumes
#* rather than re-draws. A reload starts a new case, because a fresh page holds no
#* handle to send. The case's facts, its fixed inputs and the whole 43-point price
#* curve come back with it; the curve is one model run per lever value, so this is
#* the expensive call and belongs behind an explicit action.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-part2-case
function(req) {
  eqalb_tutorial_part2_case(parse_body(req))
}

#* Guided Tutorial Part 2 value-for-money result for one case and one negotiated
#* price: the current-price card, the highest acceptable price and the full price
#* curve, with every status, threshold, label, colour and sentence produced in R.
#* An optional 'curve' (the curve this case already returned) lets R re-classify
#* the curve instead of re-running it, so a price change costs one model run; R
#* performs the classification either way. Both paths return the same response.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-part2-evaluate
function(req) {
  eqalb_tutorial_part2_evaluate(parse_body(req))
}

# --- Guided Tutorial journey -------------------------------------------------

#* Guided Tutorial journey contract: the fixed case, its two options and the
#* explanations the case brief keeps behind disclosures, the chapter list this
#* slice implements, and Chapter 1's wording, expected answers and one price
#* lever. No model run happens to build it.
#*
#* The path is flat for the same reason Part 1's is: plumber cannot hold a route
#* and a nested route that share a prefix, so /api/tutorial/journey cannot sit
#* beside /api/tutorial. The published contract is GET /api/tutorial/journey,
#* which the FastAPI service serves and maps here.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @get /api/tutorial-journey
function() {
  eqalb_journey_contract()
}

#* Guided Tutorial journey base case for one price and one no-event utility: the
#* incremental cost, the incremental QALYs, R's formatted ICER, the result table and
#* plane, R's teaching status with its interpretation, and R's plain-language reading
#* of the numbers. The request carries the two levers only; every other assumption is
#* the case's own fixed value, so a journey request cannot read a dashboard or Part 1
#* setting. The same body always returns the same response.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-base-case
function(req) {
  eqalb_journey_base_case(parse_body(req))
}

#* Probabilistic sensitivity analysis for the journey's second chapter. The
#* repeats are produced by run_psa_eqalb(), the same function the analysis
#* dashboard uses, and the deterministic comparison at the same price and utility is
#* returned alongside them so the chapter's point and its cloud cannot disagree. The
#* utility enters as the mean of the analysis's existing beta for that parameter.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-uncertainty
function(req) {
  eqalb_journey_uncertainty(parse_body(req))
}

#* The journey's third chapter: one-way sensitivity analysis, ranked twice. Both
#* rankings come from run_eqalb_owsa(), the same analysis the sensitivity tab uses,
#* given the learner's price and utility and the ranges R derives from that scenario.
#* No threshold, net monetary benefit or decision is returned: the chapter ranks how
#* far a single assumption moves the extra cost and then the extra health.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-sensitivity
function(req) {
  eqalb_journey_sensitivity(parse_body(req))
}

#* The journey's fourth chapter: what better evidence would be worth. The value is
#* computed from the PSA rows the client holds - the same rows the uncertainty
#* chapter returned for this price and utility - so no simulation runs here. Both
#* figures come from voi_evpi() and voi_evppi(), the functions the
#* value-of-information tab uses, and are per person. The rows are validated with the
#* same helper /api/value-of-information uses.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-voi
function(req) {
  body <- parse_body(req)
  body$results <- model_results_from_body(body)
  eqalb_journey_voi(body)
}

#* The journey's fifth chapter: where the price has to sit for the balance to hold.
#* The balance is one run of the same model the base case uses, and the price at
#* which the balance reaches zero comes from eqalb_price_solve(), the solver the
#* value-based-price analysis uses. An optional 'solve' (the solve this chapter
#* already returned) lets a repeat request reuse it instead of solving again; its
#* shape and its scenario key are validated first, so a solve computed at a different
#* price scenario or utility is refused. It only ever supplies the marker - the
#* balance beside it is always computed here.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-price
function(req) {
  eqalb_journey_price(parse_body(req))
}

#* The journey's sixth chapter: what adoption would cost the payer. Every figure comes
#* from calculate_budget_impact(), the function the budget-impact tab and Part 2 use,
#* so no model runs here. The response carries the whole coverage sweep for the one
#* price the journey carries, so moving the coverage cap selects a row R has already
#* computed instead of asking again. Budget impact does not read the utility: the
#* calculator prices active users and has no quality-of-life term.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-budget
function(req) {
  eqalb_journey_budget(parse_body(req))
}

#* The journey's seventh chapter: can the technology be delivered as planned? Every
#* status comes from calculate_readiness(), the function the DHT-readiness tab and
#* Part 2 use, so no model runs here and no threshold is restated. The request carries
#* only the four answers the chapter asks for; the case's own access shares, engagement
#* values and accessibility are read in R and cannot be moved by a request, so this
#* chapter cannot change the economics the earlier chapters computed.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-readiness
function(req) {
  eqalb_journey_readiness(parse_body(req))
}

#* The journey's eighth and last chapter: time to a first heart attack or stroke. The
#* curves come from simulate_eqalb_survival(), the function the Simulated survival tab
#* runs, at the case's own effect assumption and the model's own annual event risks.
#* No model runs here, no price and no quality-of-life score is read, and no p-value,
#* hazard ratio or median is returned: the chapter reads the two curves at three times
#* and compares the two estimates at one of them. The request carries no body, so the
#* same seed always returns the same figure.
#* @serializer json list(auto_unbox = TRUE, digits = NA)
#* @post /api/tutorial-journey-survival
function(req) {
  eqalb_journey_survival()
}

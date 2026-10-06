# eQalb plus usual care versus usual care alone
# 10-year cohort Markov model with annual cycles.
# Supplied inputs are entered below; follow-up event costs remain provisional.
# Requires heemod; install with install.packages("heemod") if needed.

suppressPackageStartupMessages(library(heemod))
suppressPackageStartupMessages(library(ggplot2))

# Clinical inputs supplied for this analysis
cycles <- 10
p_mi_usual_care <- 0.015
p_stroke_usual_care <- 0.010
p_other_death <- 0.020
p_death_post_mi <- 0.050
p_death_post_stroke <- 0.060
engagement_year_1 <- 0.70
engagement_years_2_to_10 <- 0.42

# Economic inputs: German payer perspective, 2025 euros, per person.
cost_no_event <- 0
cost_post_mi_year1 <- 14315
cost_post_mi_followup <- 6000       # PLACEHOLDER: needs source.
cost_post_stroke_year1 <- 19677
cost_post_stroke_followup <- 6496   # PLACEHOLDER: needs source.
utility_no_event <- 0.86             # EQ-5D-based, age-adjusted.
utility_post_mi <- 0.80              # EQ-5D-based, age-adjusted.
utility_post_stroke <- 0.60          # EQ-5D-based, age-adjusted.
discount_rate_cost <- 0.03
discount_rate_effect <- 0.03
intervention_price_annual <- 360
implementation_cost <- 40
healthcare_use_savings_annual <- 20

# Relative risk reduction scenarios; use evidence to justify this range.
rrr_base <- 0.10
rrr_low <- 0.05
rrr_high <- 0.15

# Exploratory one-way ranges. These are scenario bounds, not confidence limits;
# replace them with local pricing, implementation, utilization, and clinical evidence.
sensitivity_ranges <- data.frame(
  parameter = c(
    "Annual intervention price",
    "Implementation cost",
    "Annual healthcare-use savings",
    "Relative risk reduction",
    "Year-1 engagement",
    "Follow-up engagement",
    "No-event utility",
    "Post-MI utility",
    "Post-stroke utility",
    "Cost discount rate",
    "Effect discount rate"
  ),
  argument = c(
    "scenario_intervention_price", "scenario_implementation_cost",
    "scenario_healthcare_savings", "scenario_rrr",
    "scenario_engagement_year1", "scenario_engagement_followup",
    "scenario_utility_no_event", "scenario_utility_post_mi",
    "scenario_utility_post_stroke", "scenario_discount_rate_cost",
    "scenario_discount_rate_effect"
  ),
  # Price +/-20% reflects plausible contracting and subscription variation.
  low = c(288, 20, 10, rrr_low, 0.60, 0.32, 0.81, 0.75, 0.55, 0.00, 0.00),
  high = c(432, 60, 30, rrr_high, 0.80, 0.52, 0.91, 0.85, 0.65, 0.06, 0.06),
  stringsAsFactors = FALSE
)
# Implementation +/-50% reflects uncertainty in start-up staffing and setup.
# Savings +/-50% reflects uncertainty in whether modeled utilization reductions occur.
# RRR 5%-15% brackets the supplied 10% base assumption.
# Engagement bounds vary each supplied rate by 10 absolute percentage points.
# Utility bounds vary each EQ-5D state utility by 0.05, a modest absolute change.
# Discounting ranges from 0% to 6%, spanning no discount to twice the 3% base rate.

if (any(c(p_mi_usual_care, p_stroke_usual_care, p_other_death,
          p_death_post_mi, p_death_post_stroke,
          engagement_year_1, engagement_years_2_to_10,
            rrr_base, rrr_low, rrr_high) < 0) ||
    any(c(p_mi_usual_care, p_stroke_usual_care, p_other_death,
          p_death_post_mi, p_death_post_stroke,
          engagement_year_1, engagement_years_2_to_10,
            rrr_base, rrr_low, rrr_high) > 1)) {
  stop("Probabilities, engagement rates, and relative risk reductions must be in [0, 1].",
       call. = FALSE)
}

if (p_mi_usual_care + p_stroke_usual_care + p_other_death > 1) {
  stop("Usual-care event probabilities cannot sum to more than 1.", call. = FALSE)
}
if (rrr_low > rrr_base || rrr_high < rrr_base) {
  stop("The sensitivity range must bracket the base-case relative risk reduction.",
       call. = FALSE)
}

# nolint start: object_usage_linter
run_markov <- function(
  scenario_rrr = rrr_base,
  scenario_intervention_price = intervention_price_annual,
  scenario_implementation_cost = implementation_cost,
  scenario_healthcare_savings = healthcare_use_savings_annual,
  scenario_engagement_year1 = engagement_year_1,
  scenario_engagement_followup = engagement_years_2_to_10,
  scenario_utility_no_event = utility_no_event,
  scenario_utility_post_mi = utility_post_mi,
  scenario_utility_post_stroke = utility_post_stroke,
  scenario_discount_rate_cost = discount_rate_cost,
  scenario_discount_rate_effect = discount_rate_effect,
  scenario_cost_post_mi_year1 = cost_post_mi_year1,
  scenario_cost_post_mi_followup = cost_post_mi_followup,
  scenario_cost_post_stroke_year1 = cost_post_stroke_year1,
  scenario_cost_post_stroke_followup = cost_post_stroke_followup,
  scenario_cycles = cycles
) {
  parameters <- define_parameters(
    p_mi = p_mi_usual_care,
    p_stroke = p_stroke_usual_care,
    p_other_death = p_other_death,
    p_death_mi = p_death_post_mi,
    p_death_stroke = p_death_post_stroke,
    engagement_year1 = scenario_engagement_year1,
    engagement_followup = scenario_engagement_followup,
    engagement = ifelse(model_time == 1, engagement_year1, engagement_followup),
    rrr = scenario_rrr,
    p_mi_engaged = p_mi * (1 - rrr),
    p_stroke_engaged = p_stroke * (1 - rrr),
    p_mi_effective = (1 - engagement) * p_mi + engagement * p_mi_engaged,
    p_stroke_effective = (1 - engagement) * p_stroke + engagement * p_stroke_engaged,
    cost_no_event = cost_no_event,
    cost_post_mi_year1 = scenario_cost_post_mi_year1,
    cost_post_mi_followup = scenario_cost_post_mi_followup,
    cost_post_stroke_year1 = scenario_cost_post_stroke_year1,
    cost_post_stroke_followup = scenario_cost_post_stroke_followup,
    utility_no_event = scenario_utility_no_event,
    utility_post_mi = scenario_utility_post_mi,
    utility_post_stroke = scenario_utility_post_stroke,
    discount_rate_cost = scenario_discount_rate_cost,
    discount_rate_effect = scenario_discount_rate_effect,
    intervention_price = scenario_intervention_price,
    implementation = scenario_implementation_cost,
    healthcare_savings = scenario_healthcare_savings
  )

  transition_usual_care <- define_transition(
    state_names = c("NoEvent", "PostMI", "PostStroke", "Death"),
    1 - p_mi - p_stroke - p_other_death, p_mi, p_stroke, p_other_death,
    0, 1 - p_death_mi, 0, p_death_mi,
    0, 0, 1 - p_death_stroke, p_death_stroke,
    0, 0, 0, 1
  )

  transition_eqalb <- define_transition(
    state_names = c("NoEvent", "PostMI", "PostStroke", "Death"),
    # Non-engaged users retain usual-care risk; only the engaged fraction has reduced risk.
    1 - p_mi_effective - p_stroke_effective - p_other_death,
    p_mi_effective,
    p_stroke_effective,
    p_other_death,
    0, 1 - p_death_mi, 0, p_death_mi,
    0, 0, 1 - p_death_stroke, p_death_stroke,
    0, 0, 0, 1
  )

  usual_care <- define_strategy(
    transition = transition_usual_care,
    NoEvent = define_state(
      cost = discount(cost_no_event, discount_rate_cost, time = model_time),
      effect = discount(utility_no_event, discount_rate_effect, time = model_time)
    ),
    PostMI = define_state(
      cost = discount(
        ifelse(state_time == 1, cost_post_mi_year1, cost_post_mi_followup),
        discount_rate_cost,
        time = model_time
      ),
      effect = discount(utility_post_mi, discount_rate_effect, time = model_time)
    ),
    PostStroke = define_state(
      cost = discount(
        ifelse(state_time == 1, cost_post_stroke_year1, cost_post_stroke_followup),
        discount_rate_cost,
        time = model_time
      ),
      effect = discount(utility_post_stroke, discount_rate_effect, time = model_time)
    ),
    Death = define_state(cost = 0, effect = 0)
  )

  eqalb <- define_strategy(
    transition = transition_eqalb,
    NoEvent = define_state(
      cost = discount(
        cost_no_event + intervention_price +
          ifelse(model_time == 1, implementation, 0) - healthcare_savings,
        discount_rate_cost,
        time = model_time
      ),
      effect = discount(utility_no_event, discount_rate_effect, time = model_time)
    ),
    PostMI = define_state(
      cost = discount(
        ifelse(state_time == 1, cost_post_mi_year1, cost_post_mi_followup) +
          intervention_price +
          ifelse(model_time == 1, implementation, 0) - healthcare_savings,
        discount_rate_cost,
        time = model_time
      ),
      effect = discount(utility_post_mi, discount_rate_effect, time = model_time)
    ),
    PostStroke = define_state(
      cost = discount(
        ifelse(state_time == 1, cost_post_stroke_year1, cost_post_stroke_followup) +
          intervention_price +
          ifelse(model_time == 1, implementation, 0) - healthcare_savings,
        discount_rate_cost,
        time = model_time
      ),
      effect = discount(utility_post_stroke, discount_rate_effect, time = model_time)
    ),
    Death = define_state(cost = 0, effect = 0)
  )

  # Normalize the starting cohort to one person; outputs are per person.
  run_model(
    UsualCare = usual_care,
    eQalb = eqalb,
    parameters = parameters,
    cycles = scenario_cycles,
    cost = cost,
    effect = effect,
    method = "life-table",
    init = c(NoEvent = 1, PostMI = 0, PostStroke = 0, Death = 0)
  )
}
# nolint end: object_usage_linter

summarize_model <- function(model) {
  strategy_values <- model$run_model
  usual_care <- strategy_values[strategy_values$.strategy_names == "UsualCare", ]
  eqalb <- strategy_values[strategy_values$.strategy_names == "eQalb", ]
  incremental_cost <- eqalb$.cost - usual_care$.cost
  incremental_qalys <- eqalb$.effect - usual_care$.effect

  c(
    incremental_cost = incremental_cost,
    incremental_qalys = incremental_qalys,
    icer = if (incremental_qalys == 0) NA_real_ else incremental_cost / incremental_qalys
  )
}

run_eqalb_model <- function(
  scenario_intervention_price = intervention_price_annual,
  scenario_implementation_cost = implementation_cost,
  scenario_healthcare_savings = healthcare_use_savings_annual,
  scenario_rrr = rrr_base,
  scenario_engagement_year1 = engagement_year_1,
  scenario_engagement_followup = engagement_years_2_to_10,
  scenario_utility_no_event = utility_no_event,
  scenario_utility_post_mi = utility_post_mi,
  scenario_utility_post_stroke = utility_post_stroke,
  scenario_cost_post_mi_year1 = cost_post_mi_year1,
  scenario_cost_post_mi_followup = cost_post_mi_followup,
  scenario_cost_post_stroke_year1 = cost_post_stroke_year1,
  scenario_cost_post_stroke_followup = cost_post_stroke_followup,
  scenario_discount_rate_cost = discount_rate_cost,
  scenario_discount_rate_effect = discount_rate_effect,
  scenario_cycles = cycles
) {
  model <- run_markov(
    scenario_rrr = scenario_rrr,
    scenario_intervention_price = scenario_intervention_price,
    scenario_implementation_cost = scenario_implementation_cost,
    scenario_healthcare_savings = scenario_healthcare_savings,
    scenario_engagement_year1 = scenario_engagement_year1,
    scenario_engagement_followup = scenario_engagement_followup,
    scenario_utility_no_event = scenario_utility_no_event,
    scenario_utility_post_mi = scenario_utility_post_mi,
    scenario_utility_post_stroke = scenario_utility_post_stroke,
    scenario_cost_post_mi_year1 = scenario_cost_post_mi_year1,
    scenario_cost_post_mi_followup = scenario_cost_post_mi_followup,
    scenario_cost_post_stroke_year1 = scenario_cost_post_stroke_year1,
    scenario_cost_post_stroke_followup = scenario_cost_post_stroke_followup,
    scenario_discount_rate_cost = scenario_discount_rate_cost,
    scenario_discount_rate_effect = scenario_discount_rate_effect,
    scenario_cycles = scenario_cycles
  )
  summary <- summarize_model(model)

  list(
    incremental_cost = unname(summary["incremental_cost"]),
    incremental_qalys = unname(summary["incremental_qalys"]),
    icer = unname(summary["icer"]),
    model = model
  )
}

# Phase 1 probabilistic sensitivity analysis (PSA).
# The uncertainty distributions below are ILLUSTRATIVE educational assumptions
# for the fictional eQalb digital therapeutic. They are not
# evidence-based unless replaced with empirical parameter uncertainty.
# The intervention-price mean is supplied by the caller so the PSA is centred on
# the live global price; the uncertainty width (sd) is unchanged.
psa_parameter_table <- function(
  price = intervention_price_annual,
  implementation = implementation_cost,
  savings = healthcare_use_savings_annual,
  rrr = rrr_base,
  engagement_year1 = engagement_year_1,
  engagement_followup = engagement_years_2_to_10,
  no_event_utility = utility_no_event,
  post_mi_utility = utility_post_mi,
  post_stroke_utility = utility_post_stroke
) {
  data.frame(
    parameter = c(
      "Relative risk reduction",
      "Year-1 engagement",
      "Follow-up engagement",
      "Utility: no event",
      "Utility: post-MI",
      "Utility: post-stroke",
      "Annual intervention price",
      "Implementation cost",
      "Annual healthcare-use savings"
    ),
    model_argument = c(
      "scenario_rrr",
      "scenario_engagement_year1",
      "scenario_engagement_followup",
      "scenario_utility_no_event",
      "scenario_utility_post_mi",
      "scenario_utility_post_stroke",
      "scenario_intervention_price",
      "scenario_implementation_cost",
      "scenario_healthcare_savings"
    ),
    distribution = c(
      "beta", "beta", "beta", "beta", "beta", "beta",
      "gamma", "gamma", "gamma"
    ),
    mean = c(
      rrr, engagement_year1, engagement_followup,
      no_event_utility, post_mi_utility, post_stroke_utility,
      price, implementation,
      savings
    ),
    sd = c(0.03, 0.10, 0.10, 0.03, 0.05, 0.07, 72, 8, 4),
    stringsAsFactors = FALSE
  )
}

# Beta parameters from a mean and standard deviation, kept inside the valid
# region (variance must stay below mean * (1 - mean)).
psa_beta_parameters <- function(mean, sd) {
  mean <- min(max(mean, 1e-6), 1 - 1e-6)
  max_sd <- sqrt(mean * (1 - mean))
  sd <- min(max(sd, 1e-4), max_sd * 0.95)
  variance <- sd^2
  shape_factor <- mean * (1 - mean) / variance - 1
  c(shape1 = mean * shape_factor, shape2 = (1 - mean) * shape_factor)
}

# Gamma parameters from a mean and standard deviation (positive costs).
psa_gamma_parameters <- function(mean, sd) {
  mean <- max(mean, 1e-6)
  sd <- max(sd, 1e-6)
  c(shape = (mean / sd)^2, rate = mean / sd^2)
}

# Runs a probabilistic sensitivity analysis with the existing full model.
# Returns the successful simulations, requested/successful/failed counts, mean
# incremental cost and QALYs, the median interpretable ICER, the probability of
# cost-effectiveness (INMB > 0) at the supplied thresholds, and a CEAC curve.
# Probability of cost-effectiveness at a willingness-to-pay threshold, using
# the net monetary benefit rule (incremental net monetary benefit > 0).
psa_probability_cost_effective <- function(results, wtp) {
  inmb <- wtp * results$incremental_qalys - results$incremental_cost
  mean(inmb > 0)
}

run_psa_eqalb <- function(
  n_sim,
  seed,
  max_wtp,
  wtp_thresholds = c(50000, 100000, 150000),
  intervention_price = intervention_price_annual,
  implementation = implementation_cost,
  savings = healthcare_use_savings_annual,
  rrr = rrr_base,
  engagement_year1 = engagement_year_1,
  engagement_followup = engagement_years_2_to_10,
  no_event_utility = utility_no_event,
  post_mi_utility = utility_post_mi,
  post_stroke_utility = utility_post_stroke,
  parameter_table = psa_parameter_table(
    price = intervention_price,
    implementation = implementation,
    savings = savings,
    rrr = rrr,
    engagement_year1 = engagement_year1,
    engagement_followup = engagement_followup,
    no_event_utility = no_event_utility,
    post_mi_utility = post_mi_utility,
    post_stroke_utility = post_stroke_utility
  ),
  progress = NULL
) {
  n_sim <- as.integer(n_sim)
  # A single explicit seed makes the whole analysis reproducible for that seed.
  set.seed(as.integer(seed))
  # Report progress about every 1% of simulations, and at least every 50.
  progress_stride <- max(1L, min(50L, as.integer(ceiling(n_sim / 100))))

  simulations <- vector("list", n_sim)
  failures <- character(0)

  for (i in seq_len(n_sim)) {
    simulation <- tryCatch({
      sample_args <- list()
      for (j in seq_len(nrow(parameter_table))) {
        row <- parameter_table[j, ]
        draw <- if (identical(row$distribution, "beta")) {
          params <- psa_beta_parameters(row$mean, row$sd)
          stats::rbeta(1, params[["shape1"]], params[["shape2"]])
        } else {
          params <- psa_gamma_parameters(row$mean, row$sd)
          stats::rgamma(1, shape = params[["shape"]], rate = params[["rate"]])
        }
        sample_args[[row$model_argument]] <- draw
      }
      model <- suppressMessages(do.call(run_eqalb_model, sample_args))
      if (!is.finite(model$incremental_cost) ||
        !is.finite(model$incremental_qalys)) {
        stop("non-finite incremental result", call. = FALSE)
      }
      data.frame(
        simulation = i,
        incremental_cost = model$incremental_cost,
        incremental_qalys = model$incremental_qalys,
        icer = if (model$incremental_qalys > 0) {
          model$incremental_cost / model$incremental_qalys
        } else {
          NA_real_
        },
        # Preserve the sampled parameter draws (one column per sampled
        # parameter) so value-of-information analysis can condition on them.
        as.data.frame(sample_args, stringsAsFactors = FALSE)
      )
    }, error = function(error) {
      failures <<- c(failures, conditionMessage(error))
      NULL
    })
    simulations[[i]] <- simulation

    if (!is.null(progress) && (i %% progress_stride == 0L || i == n_sim)) {
      progress(i, n_sim)
    }
  }

  successful <- do.call(rbind, Filter(Negate(is.null), simulations))
  if (is.null(successful) || nrow(successful) == 0L) {
    stop("No PSA simulations completed successfully.", call. = FALSE)
  }
  rownames(successful) <- NULL

  interpretable_icer <- successful$icer[is.finite(successful$icer)]
  median_icer <- if (length(interpretable_icer) > 0L) {
    stats::median(interpretable_icer)
  } else {
    NA_real_
  }

  probability_cost_effective <- vapply(
    wtp_thresholds,
    function(threshold) psa_probability_cost_effective(successful, threshold),
    numeric(1)
  )
  names(probability_cost_effective) <- format(
    wtp_thresholds,
    big.mark = ",",
    scientific = FALSE,
    trim = TRUE
  )

  wtp_grid <- seq(0, max_wtp, length.out = 201)
  # Each WTP row must be paired with the same simulation-specific incremental
  # cost, so repeat the cost vector once per WTP grid point (column-major).
  inmb_matrix <- outer(wtp_grid, successful$incremental_qalys) -
    rep(successful$incremental_cost, each = length(wtp_grid))

  list(
    results = successful,
    n_requested = n_sim,
    n_successful = nrow(successful),
    n_failed = n_sim - nrow(successful),
    failures = failures,
    mean_incremental_cost = mean(successful$incremental_cost),
    mean_incremental_qalys = mean(successful$incremental_qalys),
    median_icer = median_icer,
    wtp_thresholds = wtp_thresholds,
    probability_cost_effective = probability_cost_effective,
    ceac = data.frame(
      wtp = wtp_grid,
      probability = rowMeans(inmb_matrix > 0)
    )
  )
}

# Value-of-information helpers.
# These reuse the PSA simulations already stored in the PSA results and do not
# rerun the economic model. All values are per patient.

# Tiny negative values caused only by floating-point rounding are set to zero;
# larger negative values are returned unchanged so that an implementation error
# is visible rather than silently hidden.
clamp_non_negative <- function(value, tolerance) {
  ifelse(!is.na(value) & value < 0 & value >= -tolerance, 0, value)
}

# Expected value of perfect information per patient, at a willingness-to-pay
# threshold, from the stored PSA results.
# Usual care has incremental NMB identically zero, so
#   EVPI = mean(max(NMB_i, 0)) - max(mean(NMB_i), 0).
voi_evpi <- function(results, wtp, tolerance = 1e-6) {
  nmb <- wtp * results$incremental_qalys - results$incremental_cost
  mean_nmb <- mean(nmb)
  expected_nmb_perfect <- mean(pmax(nmb, 0))
  expected_nmb_current <- max(mean_nmb, 0)
  raw_evpi <- expected_nmb_perfect - expected_nmb_current
  list(
    n = length(nmb),
    mean_incremental_cost = mean(results$incremental_cost),
    mean_incremental_qalys = mean(results$incremental_qalys),
    mean_nmb = mean_nmb,
    expected_nmb_perfect = expected_nmb_perfect,
    expected_nmb_current = expected_nmb_current,
    evpi = clamp_non_negative(raw_evpi, tolerance),
    evpi_raw = raw_evpi,
    clamped = !is.na(raw_evpi) && raw_evpi < 0 && raw_evpi >= -tolerance
  )
}

# Single-loop approximation of the conditional expected NMB given one parameter:
# a natural cubic spline regression of NMB on the sampled parameter values.
# Falls back to the unconditional mean when the fit is not possible.
voi_conditional_mean_nmb <- function(theta, nmb, spline_df = 3L) {
  if (length(unique(theta)) < (spline_df + 2L)) {
    return(rep(mean(nmb), length(theta)))
  }
  fit <- tryCatch(
    stats::lm(nmb ~ splines::ns(theta, df = spline_df)),
    error = function(error) NULL
  )
  if (is.null(fit)) {
    return(rep(mean(nmb), length(theta)))
  }
  conditional <- tryCatch(
    stats::predict(fit, newdata = data.frame(theta = theta)),
    error = function(error) rep(mean(nmb), length(theta))
  )
  as.numeric(conditional)
}

# Regression-based single-loop EVPPI per patient for each sampled parameter that
# is present in the returned PSA draws. This is an approximation, not a nested
# Monte Carlo estimate.
voi_evppi <- function(
  results,
  wtp,
  parameter_table = psa_parameter_table(),
  tolerance = 1e-6,
  min_simulations = 100L,
  spline_df = 3L
) {
  available_arguments <- parameter_table$model_argument[
    parameter_table$model_argument %in% names(results)
  ]
  if (length(available_arguments) == 0L) {
    return(list(
      available = FALSE,
      reason = paste(
        "EVPPI is not shown: the PSA results do not contain the sampled",
        "parameter values. Rerun the PSA to store them."
      )
    ))
  }
  n <- nrow(results)
  if (n < min_simulations) {
    return(list(
      available = FALSE,
      reason = sprintf(
        paste(
          "EVPPI is not shown: the regression-based approximation requires at",
          "least %d successful PSA simulations and only %d are available.",
          "Show EVPI only, or run a larger PSA."
        ),
        min_simulations, n
      )
    ))
  }

  nmb <- wtp * results$incremental_qalys - results$incremental_cost
  baseline <- max(mean(nmb), 0)
  evpi <- mean(pmax(nmb, 0)) - baseline

  rows <- lapply(available_arguments, function(argument) {
    conditional <- voi_conditional_mean_nmb(
      results[[argument]], nmb, spline_df = spline_df
    )
    raw <- mean(pmax(conditional, 0)) - baseline
    data.frame(
      parameter = parameter_table$parameter[
        match(argument, parameter_table$model_argument)
      ],
      model_argument = argument,
      evppi = clamp_non_negative(raw, tolerance),
      evppi_raw = raw,
      clamped = raw < 0 && raw >= -tolerance,
      stringsAsFactors = FALSE
    )
  })
  table <- do.call(rbind, rows)
  table <- table[order(table$evppi, decreasing = TRUE), , drop = FALSE]
  rownames(table) <- NULL

  list(
    available = TRUE,
    table = table,
    evpi = evpi,
    any_clamped = any(table$clamped),
    exceeds = any(table$evppi > evpi + tolerance)
  )
}

# Educational EVPI magnitude bands, in euros per patient. These are
# presentation rules for this teaching app, not official HTA or research
# priority thresholds.
VOI_EVPI_BANDS <- c(negligible = 1, modest = 100, moderate = 1000)

voi_format_euros <- function(value) {
  paste0(
    "\u20ac",
    format(round(value, 2),
           nsmall = 2, big.mark = ",", scientific = FALSE, trim = TRUE)
  )
}

voi_capitalize <- function(text) {
  if (length(text) == 0L || is.na(text) || !nzchar(text)) {
    return(text)
  }
  paste0(toupper(substr(text, 1, 1)), substr(text, 2, nchar(text)))
}

# Magnitude word for an EVPI per patient, using VOI_EVPI_BANDS.
voi_evpi_magnitude <- function(evpi) {
  if (length(evpi) == 0L || is.na(evpi)) {
    return("not estimable")
  }
  if (evpi <= VOI_EVPI_BANDS[["negligible"]]) {
    "negligible"
  } else if (evpi <= VOI_EVPI_BANDS[["modest"]]) {
    "modest"
  } else if (evpi <= VOI_EVPI_BANDS[["moderate"]]) {
    "moderate"
  } else {
    "material"
  }
}

# Traffic-light interpretation of decision uncertainty for the VOI tab.
# Presentation only: it reads the already-computed EVPI and the probability of
# cost-effectiveness and does not change any calculation.
#
# Educational rules:
#   Red   - high decision uncertainty: the less-preferred option wins in at
#           least 40% of simulations (the decision is close to a coin flip), or
#           EVPI per patient is material (above EUR 1,000).
#   Amber - low-to-moderate: at least 1% of simulations favour the
#           less-preferred option, or EVPI per patient is above negligible.
#   Green - low: the preferred option wins in at least 99% of simulations and
#           EVPI per patient is negligible (EUR 1 or less).
voi_uncertainty_status <- function(
  probability_cost_effective,
  evpi,
  mean_nmb,
  tolerance = 1e-6
) {
  probability <- suppressWarnings(
    min(max(as.numeric(probability_cost_effective), 0), 1)
  )
  preferred <- if (is.na(mean_nmb)) {
    NA_character_
  } else if (mean_nmb > tolerance) {
    "eQalb"
  } else if (mean_nmb < -tolerance) {
    "usual care"
  } else {
    NA_character_
  }
  # Share of simulations in which the less-preferred option wins. NA when the
  # probability of cost-effectiveness is not available.
  p_loser <- if (length(probability) == 0L || is.na(probability)) {
    NA_real_
  } else {
    min(probability, 1 - probability)
  }
  magnitude <- voi_evpi_magnitude(evpi)

  status <- if (is.na(p_loser)) {
    # Without a probability of cost-effectiveness the decision cannot be shown
    # as stable, so the status falls back to the EVPI magnitude alone.
    if (identical(magnitude, "material")) {
      "Red"
    } else if (identical(magnitude, "negligible")) {
      "Green"
    } else {
      "Amber"
    }
  } else if (p_loser >= 0.40 || identical(magnitude, "material")) {
    "Red"
  } else if (p_loser >= 0.01 || !identical(magnitude, "negligible")) {
    "Amber"
  } else {
    "Green"
  }

  label <- switch(status,
    Green = "Low decision uncertainty",
    Amber = "Low-to-moderate decision uncertainty",
    Red = "High decision uncertainty"
  )

  other <- if (is.na(preferred)) {
    NA_character_
  } else if (identical(preferred, "eQalb")) {
    "usual care"
  } else {
    "eQalb"
  }

  decision_text <- if (is.na(preferred)) {
    paste(
      "Neither option is clearly preferred at this threshold: the mean",
      "incremental net monetary benefit is approximately zero."
    )
  } else if (is.na(p_loser)) {
    sprintf(
      paste(
        "%s is preferred on average, but the probability that it is",
        "cost-effective could not be estimated at this threshold."
      ),
      voi_capitalize(preferred)
    )
  } else if (p_loser <= 1e-9) {
    sprintf("%s is preferred in all simulations.", voi_capitalize(preferred))
  } else if (p_loser <= 0.20) {
    sprintf(
      paste(
        "%s is clearly preferred in most simulations, but %s is preferred in",
        "a small number of scenarios."
      ),
      voi_capitalize(preferred), other
    )
  } else if (p_loser < 0.40) {
    sprintf(
      paste(
        "%s is preferred, but %s is preferred in a substantial minority of",
        "simulations."
      ),
      voi_capitalize(preferred), other
    )
  } else {
    sprintf(
      paste(
        "%s is preferred on average, but the decision is close: %s is",
        "preferred in a similar share of simulations."
      ),
      voi_capitalize(preferred), other
    )
  }

  evpi_text <- if (is.na(evpi)) {
    "The value of perfect information could not be estimated."
  } else {
    sprintf(
      paste(
        "Perfect information would be worth about %s per patient at this",
        "threshold."
      ),
      voi_format_euros(evpi)
    )
  }

  status_text <- switch(status,
    Green = paste(
      "This means the current decision is stable and further evidence is",
      "unlikely to change it at this threshold."
    ),
    Amber = paste(
      "This means there is some uncertainty, but the current decision is",
      "fairly stable."
    ),
    Red = paste(
      "This means the decision is genuinely uncertain at this threshold, so",
      "further evidence could change it."
    )
  )

  what_this_means <- paste(
    switch(magnitude,
      negligible = paste(
        "Further evidence is unlikely to be valuable: the maximum theoretical",
        "value of removing all uncertainty is negligible on a per-patient",
        "basis."
      ),
      modest = paste(
        "Further evidence could be useful, but the maximum theoretical value",
        "of removing all uncertainty is modest on a per-patient basis."
      ),
      moderate = paste(
        "Further evidence could be valuable: the maximum theoretical value of",
        "removing all uncertainty is moderate on a per-patient basis."
      ),
      material = paste(
        "Further evidence is likely to be valuable: the maximum theoretical",
        "value of removing all uncertainty is material on a per-patient basis."
      ),
      paste(
        "The maximum theoretical value of removing all uncertainty could not",
        "be estimated on a per-patient basis."
      )
    ),
    "This is not a research budget and does not account for the cost,",
    "feasibility, or time required to collect evidence."
  )

  thresholds <- paste(
    "Educational traffic-light rules:",
    "Red if the less-preferred option wins in at least 40% of simulations or",
    "EVPI per patient is above \u20ac1,000;",
    "Green if it wins in at most 1% of simulations and EVPI per patient is",
    "\u20ac1 or less; Amber otherwise."
  )

  list(
    status = status,
    label = label,
    magnitude = magnitude,
    p_loser = p_loser,
    preferred = preferred,
    interpretation = paste(decision_text, evpi_text, status_text),
    what_this_means = what_this_means,
    thresholds = thresholds
  )
}

# Educational thresholds for the HTA decision-summary tab. These are
# presentation rules for this teaching app, not official NICE or payer criteria.
HTA_SUMMARY_THRESHOLDS <- list(
  economic_green_probability = 0.50,
  economic_red_probability = 0.05,
  budget_impact_green = 1e6,
  budget_impact_amber = 1e7,
  readiness_red_share = 0.25
)

hta_summary_money <- function(value) {
  if (length(value) == 0L || is.na(value)) {
    return("not available")
  }
  paste0(
    "\u20ac",
    format(round(value, 2), nsmall = 2, big.mark = ",", scientific = FALSE,
           trim = TRUE)
  )
}

hta_summary_percent <- function(value, digits = 1) {
  if (length(value) == 0L || is.na(value)) {
    return("not available")
  }
  paste0(format(round(100 * value, digits), nsmall = digits), "%")
}

# Traffic-light decision summary for the HTA decision-summary tab.
# Presentation only: it reads values already computed by the other tabs (base
# case, PSA, VOI, BIA and DHT readiness) and does not rerun any model.
assess_hta_decision_summary <- function(
  icer,
  reference_wtp,
  probability_cost_effective,
  mean_incremental_nmb,
  evpi,
  highest_evppi = NA_real_,
  cumulative_budget_impact,
  readiness_domains = NULL
) {
  p_ce <- suppressWarnings(
    min(max(as.numeric(probability_cost_effective), 0), 1)
  )
  if (length(p_ce) == 0L) {
    p_ce <- NA_real_
  }
  rows <- list()
  add_row <- function(domain, status, measure, basis, interpretation) {
    rows[[length(rows) + 1L]] <<- data.frame(
      Domain = domain,
      Status = status,
      Measure = measure,
      Basis = basis,
      Interpretation = interpretation,
      stringsAsFactors = FALSE
    )
  }

  # --- 1. Economic value -----------------------------------------------------
  economic <- if (is.na(icer) || is.na(p_ce) || is.na(reference_wtp)) {
    "Not available"
  } else if (p_ce >= HTA_SUMMARY_THRESHOLDS$economic_green_probability &&
               icer <= reference_wtp) {
    "Green"
  } else if (p_ce < HTA_SUMMARY_THRESHOLDS$economic_red_probability &&
               icer > reference_wtp) {
    "Red"
  } else {
    "Amber"
  }
  economic_measure <- if (is.na(icer)) {
    "not available"
  } else {
    paste0(
      "ICER ", hta_summary_money(icer), "/QALY vs reference threshold ",
      hta_summary_money(reference_wtp), "/QALY; P(cost-effective) ",
      hta_summary_percent(p_ce), "; mean incremental NMB ",
      hta_summary_money(mean_incremental_nmb)
    )
  }
  economic_interpretation <- switch(economic,
    Green = paste(
      "eQalb is cost-effective at the reference threshold in the",
      "majority of PSA simulations and the base-case ICER is below it."
    ),
    Amber = paste(
      "The economic result is borderline, or the ICER and the probability of",
      "cost-effectiveness disagree, so the conclusion depends on the assumed",
      "threshold and assumptions."
    ),
    Red = paste(
      "eQalb is not cost-effective at the reference threshold in most",
      "PSA simulations and the base-case ICER is above it."
    ),
    paste("Not yet assessable: run the base case and the PSA.")
  )
  add_row("Economic value", economic, economic_measure,
          "Base-case ICER, reference WTP and PSA probability", 
          economic_interpretation)

  # --- 2. Decision uncertainty (reuses the VOI rule) -------------------------
  uncertainty <- if (is.na(p_ce) || is.na(evpi)) {
    "Not available"
  } else {
    voi_uncertainty_status(
      probability_cost_effective = p_ce,
      evpi = evpi,
      mean_nmb = mean_incremental_nmb
    )
  }
  uncertainty_status <- if (is.list(uncertainty)) uncertainty$status else uncertainty
  uncertainty_label <- if (is.list(uncertainty)) uncertainty$label else
    "not yet assessable"
  add_row(
    "Decision uncertainty",
    uncertainty_status,
    paste0(
      "EVPI ", hta_summary_money(evpi), " per patient; P(cost-effective) ",
      hta_summary_percent(p_ce),
      if (is.na(highest_evppi)) "" else paste0(
        "; highest EVPPI ", hta_summary_money(highest_evppi), " per patient"
      )
    ),
    "EVPI per patient and the probability of cost-effectiveness",
    if (is.list(uncertainty)) {
      paste(uncertainty$label, "-", uncertainty$interpretation)
    } else {
      "Not yet assessable: run the PSA."
    }
  )

  # --- 3. Budget impact -----------------------------------------------------
  budget <- if (is.na(cumulative_budget_impact)) {
    "Not available"
  } else if (cumulative_budget_impact <= HTA_SUMMARY_THRESHOLDS$budget_impact_green) {
    "Green"
  } else if (cumulative_budget_impact <= HTA_SUMMARY_THRESHOLDS$budget_impact_amber) {
    "Amber"
  } else {
    "Red"
  }
  budget_interpretation <- switch(budget,
    Green = "Low five-year cumulative net budget impact under the selected uptake assumptions.",
    Amber = "Moderate five-year cumulative net budget impact; affordability depends on uptake and price.",
    Red = "High five-year cumulative net budget impact; affordability is a material barrier under the selected uptake assumptions.",
    paste("Not yet assessable: run the budget-impact analysis.")
  )
  add_row("Budget impact", budget,
          paste0("Five-year cumulative net budget impact ",
                 hta_summary_money(cumulative_budget_impact)),
          "Budget-impact analysis over the selected horizon",
          budget_interpretation)

  # --- 4. Clinical evidence maturity ---------------------------------------
  add_row(
    "Clinical evidence maturity",
    "Red",
    "Simulated illustrative data",
    "Kaplan-Meier simulation and modelled clinical inputs",
    paste(
      "The clinical outcome evidence in this app is simulated illustrative",
      "data, not observed clinical evidence, so this domain is always Red."
    )
  )

  # --- 5. Implementation readiness -----------------------------------------
  readiness <- if (is.null(readiness_domains) ||
                   !is.data.frame(readiness_domains) ||
                   nrow(readiness_domains) == 0L ||
                   !("Status" %in% names(readiness_domains))) {
    "Not available"
  } else {
    statuses <- readiness_domains$Status
    n_total <- length(statuses)
    red_share <- sum(statuses == "Red") / n_total
    if (red_share > HTA_SUMMARY_THRESHOLDS$readiness_red_share) {
      "Red"
    } else if (all(statuses == "Green")) {
      "Green"
    } else {
      "Amber"
    }
  }
  readiness_counts <- if (identical(readiness, "Not available")) {
    "not available"
  } else {
    statuses <- readiness_domains$Status
    paste0(
      sum(statuses == "Green"), " Green, ", sum(statuses == "Amber"),
      " Amber, ", sum(statuses == "Red"), " Red across ",
      length(statuses), " illustrative domains"
    )
  }
  add_row(
    "Implementation readiness",
    readiness,
    readiness_counts,
    "DHT Readiness & Implementation assessment",
    switch(readiness,
      Green = "No obvious implementation barrier under the selected assumptions.",
      Amber = paste(
        "Some domains need mitigation before broad deployment; see the DHT",
        "Readiness tab for the domain detail."
      ),
      Red = paste(
        "More than a quarter of the readiness domains are Red, so major",
        "barriers need resolution before broad deployment."
      ),
      paste(
        "Not yet assessable: open the DHT Readiness tab and click Assess",
        "readiness."
      )
    )
  )

  table <- do.call(rbind, rows)
  rownames(table) <- NULL

  assessed <- table$Status[table$Status %in% c("Green", "Amber", "Red")]
  overall <- if (length(assessed) == 0L) {
    "Not available"
  } else if (any(assessed == "Red")) {
    "Red"
  } else if (any(assessed == "Amber")) {
    "Amber"
  } else {
    "Green"
  }

  position <- if (identical(overall, "Not available") ||
                    identical(economic, "Not available") ||
                    identical(uncertainty_status, "Not available")) {
    "Not yet assessable"
  } else if (identical(economic, "Green") &&
               !identical(uncertainty_status, "Red")) {
    "Potentially favourable"
  } else if (identical(economic, "Red") &&
               identical(uncertainty_status, "Green")) {
    "Not favourable under current assumptions"
  } else if (identical(uncertainty_status, "Red")) {
    "Further evidence required"
  } else {
    "Conditional adoption with evidence generation"
  }

  position_text <- switch(position,
    "Potentially favourable" = paste(
      "Under the selected assumptions eQalb looks favourable, but this",
      "is an illustrative educational position and not a reimbursement",
      "recommendation."
    ),
    "Conditional adoption with evidence generation" = paste(
      "eQalb may provide clinical and economic benefit under favourable",
      "assumptions, but the current conclusion remains uncertain. The clinical",
      "evidence is simulated, the budget impact may be substantial, and",
      "implementation and engagement will influence whether the modelled",
      "benefit is achieved. Conditional adoption with further evidence",
      "generation is therefore an illustrative position rather than a",
      "reimbursement recommendation."
    ),
    "Further evidence required" = paste(
      "The decision is genuinely uncertain at this threshold, so further",
      "evidence could change it. This is an illustrative educational position",
      "and not a reimbursement recommendation."
    ),
    "Not favourable under current assumptions" = paste(
      "The decision is stable against eQalb at this threshold, so",
      "further evidence is unlikely to change the conclusion under the current",
      "assumptions. This is an illustrative educational position and not a",
      "reimbursement recommendation."
    ),
    paste(
      "Not yet assessable: run the base case, the PSA and the budget-impact",
      "analysis to populate the dashboard."
    )
  )

  list(
    domains = table,
    overall_status = overall,
    position = position,
    interpretation = paste(
      position_text,
      "Simulated illustrative analysis — not clinical evidence and not an",
      "official HTA recommendation."
    )
  )
}

# Dynamic evidence-priority table for the HTA decision-summary tab.
# Presentation only: it combines the values already computed by the other tabs
# with an educational description of each evidence gap. EVPPI is used only as
# supporting signal; priority comes from the dashboard domains each gap drives.
build_hta_evidence_priorities <- function(
  icer = NA_real_,
  probability_cost_effective = NA_real_,
  evpi = NA_real_,
  evppi_table = NULL,
  cumulative_budget_impact = NA_real_,
  bia_intervention_cost = NA_real_,
  bia_implementation_cost = NA_real_,
  bia_healthcare_savings = NA_real_,
  annual_price = NA_real_,
  implementation_cost_per_new_user = NA_real_,
  savings_per_active_user = NA_real_,
  rrr = NA_real_,
  engagement_year1 = NA_real_,
  engagement_followup = NA_real_,
  review_minutes = NA_real_,
  digital_access = NA_real_,
  digital_suitability = NA_real_,
  interoperability_maturity = NA_character_,
  readiness_domains = NULL,
  economic_status = NA_character_,
  uncertainty_status = NA_character_,
  budget_status = NA_character_,
  evidence_status = "Red"
) {
  evppi_for <- function(label) {
    if (is.null(evppi_table) || !is.data.frame(evppi_table) ||
          !all(c("parameter", "evppi") %in% names(evppi_table))) {
      return(NA_real_)
    }
    hit <- evppi_table$parameter == label
    if (!any(hit)) NA_real_ else evppi_table$evppi[which(hit)[1]]
  }
  readiness_for <- function(domain_name) {
    if (is.null(readiness_domains) || !is.data.frame(readiness_domains) ||
          !all(c("Domain", "Status") %in% names(readiness_domains))) {
      return(NA_character_)
    }
    hit <- readiness_domains$Domain == domain_name
    if (!any(hit)) NA_character_ else readiness_domains$Status[which(hit)[1]]
  }
  signal <- function(...) {
    parts <- c(...)
    parts <- parts[!is.na(parts) & nzchar(parts)]
    if (length(parts) == 0L) "Not yet available" else paste(parts, collapse = "; ")
  }
  value_or_na <- function(value, prefix, suffix = "") {
    if (length(value) == 0L || is.na(value)) {
      return(NA_character_)
    }
    paste0(prefix, hta_summary_money(value), suffix)
  }
  percent_or_na <- function(value, prefix, suffix = "") {
    if (length(value) == 0L || is.na(value)) {
      return(NA_character_)
    }
    paste0(prefix, hta_summary_percent(value), suffix)
  }
  # For inputs already expressed as a percentage (e.g. "85" for 85%), which must
  # not be multiplied by 100 again.
  percent_value_or_na <- function(value, prefix, suffix = "") {
    if (length(value) == 0L || is.na(value)) {
      return(NA_character_)
    }
    paste0(prefix, format(round(value, 1), nsmall = 1), "%", suffix)
  }
  # Only Green/Amber/Red count as an assessed status; "Not available" and NA
  # both mean the driving output has not been computed yet.
  assessed <- function(status) {
    status %in% c("Green", "Amber", "Red")
  }
  # Priority: driven by the least favourable dashboard domain the gap affects.
  # A gap whose driving output has not been computed is reported as
  # "Not yet available" rather than guessed.
  priority_from <- function(...) {
    statuses <- c(...)
    statuses <- statuses[assessed(statuses)]
    if (length(statuses) == 0L) {
      return("Not yet available")
    }
    if (any(statuses == "Red")) {
      "High"
    } else if (any(statuses == "Amber")) {
      "Medium"
    } else {
      "Low"
    }
  }
  # The PSA has been run once the decision-uncertainty domain is assessed, since
  # that domain depends solely on PSA outputs.
  psa_run <- assessed(uncertainty_status)

  gap <- character(0)
  signal_text <- character(0)
  status_text <- character(0)
  why <- character(0)
  needed <- character(0)
  study <- character(0)
  priority <- character(0)
  domain <- character(0)
  add <- function(g, s, st, w, n, st2, p, d) {
    gap <<- c(gap, g)
    signal_text <<- c(signal_text, s)
    status_text <<- c(status_text, st)
    why <<- c(why, w)
    needed <<- c(needed, n)
    study <<- c(study, st2)
    priority <<- c(priority, p)
    domain <<- c(domain, d)
  }

  add(
    "Relative risk reduction",
    if (psa_run) {
      signal(
        percent_or_na(rrr, "Assumed relative risk reduction "),
        value_or_na(evppi_for("Relative risk reduction"),
                    "EVPPI ", " per patient")
      )
    } else {
      "PSA not yet run"
    },
    if (psa_run) {
      "Quantified in the PSA; the assumed effect is illustrative"
    } else {
      "Not yet quantified"
    },
    "Drives the modelled event reduction and therefore the QALY gain; the assumed value is illustrative.",
    "Comparative effectiveness of the digital therapeutic on MI and stroke versus usual care.",
    "Pragmatic comparative-effectiveness study.",
    if (psa_run) {
      priority_from(economic_status, uncertainty_status)
    } else {
      "High"
    },
    if (psa_run) {
      "Economic value; Decision uncertainty"
    } else {
      "Clinical evidence maturity / decision uncertainty"
    }
  )

  engagement_signal <- signal(
    percent_or_na(engagement_year1, "Year-1 engagement "),
    percent_or_na(engagement_followup, "follow-up engagement "),
    value_or_na(evppi_for("Follow-up engagement"), "EVPPI ", " per patient")
  )
  if (identical(engagement_signal, "Not yet available")) {
    engagement_signal <- "PSA not yet run"
  }
  add(
    "Year-1 and follow-up engagement",
    engagement_signal,
    if (psa_run) {
      "Live input assumption; effective benefit scales with engagement"
    } else {
      "Not yet quantified"
    },
    "Only engaged users receive the modelled benefit, so engagement scales the effective treatment benefit.",
    "Observed adherence and retention over year 1 and beyond.",
    "Prospective real-world cohort.",
    if (psa_run) {
      priority_from(economic_status, readiness_for("Engagement"))
    } else {
      "High"
    },
    if (psa_run) {
      "Economic value; Implementation readiness"
    } else {
      "Clinical evidence maturity / decision uncertainty"
    }
  )

  add(
    "Long-term durability of benefit",
    "Benefit applied across the full model horizon with no decay",
    "Structural assumption; not represented in the PSA parameter draws",
    "The model applies benefit across the whole horizon; effect decay would reduce the QALY gain.",
    "Persistence of benefit beyond 12 months.",
    "Longitudinal follow-up.",
    priority_from(evidence_status),
    "Clinical evidence maturity; Economic value"
  )

  add(
    "MI and stroke outcomes",
    "MI and stroke risks are model constants; Kaplan-Meier events are simulated",
    if (identical(evidence_status, "Red")) {
      "Simulated illustrative data, not observed outcomes"
    } else {
      "Observed outcome data available"
    },
    "Event risk drives both QALYs and event-related costs, and no observed outcome data exist.",
    "Adjudicated cardiovascular event rates by arm.",
    "Linked EHR or claims analysis.",
    priority_from(evidence_status),
    "Clinical evidence maturity"
  )

  add(
    "Healthcare-use savings",
    signal(
      value_or_na(savings_per_active_user, "Assumed saving ",
                  " per active user per year"),
      value_or_na(bia_healthcare_savings,
                  "contributes ", " to the five-year budget impact")
    ),
    if (is.na(cumulative_budget_impact)) {
      "Not yet available"
    } else {
      "Live input assumption; offsets the intervention price in every cycle"
    },
    "The assumed saving offsets the intervention price in every cycle and feeds the budget impact.",
    "Observed change in utilisation and cost per active user.",
    "Resource-use study.",
    priority_from(budget_status, economic_status),
    "Budget impact; Economic value"
  )

  add(
    "Intervention and implementation costs",
    signal(
      value_or_na(annual_price, "Annual price "),
      value_or_na(implementation_cost_per_new_user, "implementation ",
                  " per new user"),
      value_or_na(cumulative_budget_impact,
                  "five-year cumulative net budget impact ")
    ),
    if (is.na(cumulative_budget_impact)) {
      "Not yet available"
    } else {
      "Live input assumptions; drive the budget-impact total directly"
    },
    "Price and one-off implementation cost drive incremental cost and the budget-impact total directly.",
    "Contracted price plus setup and onboarding cost.",
    "Resource-use study.",
    priority_from(budget_status, economic_status),
    "Budget impact; Economic value"
  )

  add(
    "Workflow burden and staff time",
    signal(
      if (length(review_minutes) == 0L || is.na(review_minutes)) {
        NA_character_
      } else {
        paste0(review_minutes, " clinician-review minutes per patient per month")
      },
      value_or_na(bia_implementation_cost,
                  "implementation contributes ", " to the five-year budget impact")
    ),
    if (assessed(readiness_for("Workflow burden"))) {
      "Not represented in the PSA; assessed by the DHT readiness domain"
    } else {
      "Not yet available"
    },
    "Clinician review time is the main non-price driver of implementation cost and feasibility.",
    "Measured staff time for review, onboarding and support.",
    "Implementation study.",
    priority_from(readiness_for("Workflow burden")),
    "Implementation readiness"
  )

  add(
    "Digital access and equity",
    signal(
      percent_value_or_na(digital_access, "Smartphone/internet access "),
      percent_value_or_na(digital_suitability, "digitally suitable population ")
    ),
    if (assessed(readiness_for("Equity and access")) ||
          assessed(readiness_for("Language access"))) {
      "Not represented in the PSA; assessed by the DHT readiness domains"
    } else {
      "Not yet available"
    },
    "Eligibility depends on access and suitability, so unequal access reduces reach and equity.",
    "Uptake and outcomes stratified by access, language and deprivation.",
    "Equity-stratified uptake and outcome analysis.",
    priority_from(readiness_for("Equity and access"),
                  readiness_for("Language access")),
    "Implementation readiness"
  )

  add(
    "Interoperability and implementation feasibility",
    signal(
      if (length(interoperability_maturity) == 0L ||
            is.na(interoperability_maturity)) {
        NA_character_
      } else {
        paste0("Interoperability maturity: ", interoperability_maturity)
      }
    ),
    if (assessed(readiness_for("Interoperability"))) {
      "Not represented in the PSA; assessed by the DHT readiness domain"
    } else {
      "Not yet available"
    },
    "Data-exchange maturity and algorithm governance determine whether the pathway can be deployed at scale.",
    "Technical integration and clinical-safety assessment.",
    "Technical integration assessment.",
    priority_from(readiness_for("Interoperability")),
    "Implementation readiness"
  )

  table <- data.frame(
    "Evidence gap" = gap,
    "Current model signal" = signal_text,
    "Current status" = status_text,
    "Why it matters" = why,
    "Evidence needed" = needed,
    "Suggested study or data source" = study,
    Priority = priority,
    "Dashboard domain affected" = domain,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  high <- table[["Evidence gap"]][table$Priority == "High"]
  summary <- if (length(high) == 0L) {
    "No evidence gap is currently rated high priority under the selected assumptions."
  } else {
    paste0(
      "Highest-priority current evidence gaps (rated High): ",
      paste(high, collapse = "; "), "."
    )
  }

  list(table = table, summary = summary)
}

# Phase 1 five-year budget-impact analysis (BIA).
# Illustrative payer-affordability analysis; it does not measure
# cost-effectiveness or value for money. Returns a tidy data frame with one row
# per year. Active users apply the follow-up engagement percentage to the
# cumulative treated population.
calculate_budget_impact <- function(
  population,
  year1_uptake_pct,
  annual_uptake_increase_pp,
  horizon_years,
  intervention_price,
  implementation_cost_per_new_user,
  healthcare_savings_per_active_user,
  avoided_event_savings_per_active_user,
  followup_engagement_pct
) {
  horizon_years <- as.integer(horizon_years)
  years <- seq_len(horizon_years)
  # Uptake rises each year by the annual increase, capped at 100%.
  uptake_pct <- pmin(
    100,
    year1_uptake_pct + (years - 1) * annual_uptake_increase_pp
  )
  cumulative_users <- population * uptake_pct / 100
  previous_cumulative_users <- c(
    0, cumulative_users[-length(cumulative_users)]
  )
  new_users <- cumulative_users - previous_cumulative_users
  active_users <- cumulative_users * followup_engagement_pct / 100
  gross_intervention_cost <- active_users * intervention_price
  implementation_cost <- new_users * implementation_cost_per_new_user
  healthcare_savings <- active_users * healthcare_savings_per_active_user
  avoided_event_savings <-
    active_users * avoided_event_savings_per_active_user
  net_budget_impact <- gross_intervention_cost + implementation_cost -
    healthcare_savings - avoided_event_savings

  data.frame(
    year = years,
    eligible_population = rep(population, horizon_years),
    uptake_pct = uptake_pct,
    cumulative_users = cumulative_users,
    new_users = new_users,
    active_users = active_users,
    gross_intervention_cost = gross_intervention_cost,
    implementation_cost = implementation_cost,
    healthcare_savings = healthcare_savings,
    avoided_event_savings = avoided_event_savings,
    net_budget_impact = net_budget_impact,
    cumulative_budget_impact = cumsum(net_budget_impact),
    stringsAsFactors = FALSE
  )
}

if (sys.nframe() == 0L) {
base_case <- run_markov(rrr_base)
cat("\nBase-case results (eQalb plus usual care versus usual care)\n")
print(base_case)

base_summary <- summarize_model(base_case)

# Combined engagement scenarios use both rates together: low 60%/32%, base
# 70%/42%, and high 80%/52%. These bounds reuse the one-way ranges above.
year1_engagement_range <- sensitivity_ranges[
  sensitivity_ranges$parameter == "Year-1 engagement", c("low", "high")
]
followup_engagement_range <- sensitivity_ranges[
  sensitivity_ranges$parameter == "Follow-up engagement", c("low", "high")
]
engagement_scenarios <- data.frame(
  scenario = c("Base", "Low engagement", "High engagement"),
  engagement_year1 = c(
    engagement_year_1,
    year1_engagement_range$low,
    year1_engagement_range$high
  ),
  engagement_followup = c(
    engagement_years_2_to_10,
    followup_engagement_range$low,
    followup_engagement_range$high
  ),
  stringsAsFactors = FALSE
)
engagement_scenario_results <- do.call(rbind, lapply(seq_len(nrow(engagement_scenarios)), function(i) {
  scenario <- engagement_scenarios[i, ]
  scenario_model <- if (scenario$scenario == "Base") {
    base_case
  } else {
    run_markov(
      scenario_engagement_year1 = scenario$engagement_year1,
      scenario_engagement_followup = scenario$engagement_followup
    )
  }
  scenario_summary <- summarize_model(scenario_model)

  data.frame(
    scenario = scenario$scenario,
    engagement_year1 = scenario$engagement_year1,
    engagement_followup = scenario$engagement_followup,
    incremental_cost_eur = unname(scenario_summary["incremental_cost"]),
    incremental_qalys = unname(scenario_summary["incremental_qalys"]),
    icer_eur_per_qaly = unname(scenario_summary["icer"]),
    stringsAsFactors = FALSE
  )
}))
cat("\nBase, low, and high engagement scenario results\n")
print(engagement_scenario_results, row.names = FALSE)

one_way_results <- do.call(rbind, lapply(seq_len(nrow(sensitivity_ranges)), function(i) {
  specification <- sensitivity_ranges[i, ]
  do.call(rbind, lapply(c("low", "high"), function(bound) {
    input_value <- specification[[bound]]
    scenario_arguments <- setNames(list(input_value), specification$argument)
    scenario_summary <- summarize_model(do.call(run_markov, scenario_arguments))

    data.frame(
      parameter = specification$parameter,
      bound = bound,
      input_value = input_value,
      incremental_cost_eur = unname(scenario_summary["incremental_cost"]),
      incremental_qalys = unname(scenario_summary["incremental_qalys"]),
      icer_eur_per_qaly = unname(scenario_summary["icer"]),
      stringsAsFactors = FALSE
    )
  }))
}))

base_result <- data.frame(
  parameter = "Base case",
  bound = "base",
  input_value = NA_real_,
  incremental_cost_eur = unname(base_summary["incremental_cost"]),
  incremental_qalys = unname(base_summary["incremental_qalys"]),
  icer_eur_per_qaly = unname(base_summary["icer"]),
  stringsAsFactors = FALSE
)
sensitivity_results <- rbind(base_result, one_way_results)

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
source_frames <- Filter(function(frame) !is.null(frame$ofile), sys.frames())
script_path <- if (length(script_argument) > 0L) {
  sub("^--file=", "", script_argument[[1]])
} else if (length(source_frames) > 0L) {
  source_frames[[length(source_frames)]]$ofile
} else {
  file.path(getwd(), "eqalb_markov.R")
}
output_dir <- dirname(normalizePath(script_path, mustWork = FALSE))
csv_path <- file.path(output_dir, "eqalb_owsa_results.csv")
engagement_csv_path <- file.path(output_dir, "eqalb_engagement_scenarios.csv")
png_path <- file.path(output_dir, "eqalb_icer_tornado.png")
write.csv(sensitivity_results, csv_path, row.names = FALSE)
write.csv(engagement_scenario_results, engagement_csv_path, row.names = FALSE)

tornado_data <- do.call(rbind, lapply(unique(one_way_results$parameter), function(parameter) {
  parameter_rows <- one_way_results[one_way_results$parameter == parameter, ]
  low_icer <- parameter_rows$icer_eur_per_qaly[parameter_rows$bound == "low"]
  high_icer <- parameter_rows$icer_eur_per_qaly[parameter_rows$bound == "high"]
  data.frame(
    parameter = parameter,
    low_icer = low_icer,
    high_icer = high_icer,
    impact = max(abs(c(low_icer, high_icer) - base_summary["icer"]), na.rm = TRUE)
  )
}))
tornado_data <- tornado_data[order(tornado_data$impact), ]
tornado_data$parameter <- factor(tornado_data$parameter, levels = tornado_data$parameter)
tornado_endpoints <- rbind(
  data.frame(parameter = tornado_data$parameter, icer = tornado_data$low_icer, bound = "Low"),
  data.frame(parameter = tornado_data$parameter, icer = tornado_data$high_icer, bound = "High")
)

tornado_plot <- ggplot(tornado_data, aes(y = parameter)) +
  geom_vline(xintercept = base_summary["icer"], linetype = "dashed", colour = "gray40") +
  geom_segment(
    aes(x = low_icer, xend = high_icer, yend = parameter),
    linewidth = 4,
    colour = "#287D78",
    lineend = "round"
  ) +
  geom_point(
    data = tornado_endpoints,
    aes(x = icer, y = parameter, colour = bound),
    size = 2.5,
    inherit.aes = FALSE
  ) +
  scale_colour_manual(values = c(Low = "#287D78", High = "#D37345"), name = "Input bound") +
  scale_x_continuous(labels = scales::label_number(prefix = "€", big.mark = ",")) +
  labs(
    title = "eQalb one-way sensitivity analysis",
    subtitle = "ICER impact ranked by maximum absolute change from base case",
    x = "ICER (euros per QALY)",
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(png_path, plot = tornado_plot, width = 11, height = 7, dpi = 300, bg = "white")
print(tornado_plot)
cat("\nSensitivity results saved to:", csv_path, "\n")
cat("Engagement scenarios saved to:", engagement_csv_path, "\n")
cat("Tornado diagram saved to:", png_path, "\n")
}

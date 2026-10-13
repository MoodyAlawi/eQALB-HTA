# --- Range policy ------------------------------------------------------------
#
# The one canonical OWSA range policy. R is the only place an illustrative range
# is chosen, clamped or classified: no caller derives, clamps or interprets one.
#
# Every range is an illustrative model scenario built around the value that
# parameter has in the scenario being analysed. None of them is evidence: the
# model has no confidence interval, published uncertainty range or fitted
# distribution behind any width, so no range here may be presented as one. The
# widths are deliberately the widths this model has always used, which is why the
# model's own default scenario reproduces the ranges the application has always
# shown.
#
# Three range modes:
#   frozen width          an absolute width around the current value, clamped to
#                         the parameter's permitted domain
#   policy pair           the discounting scenarios the model documents: no
#                         discounting, and twice the current rate
#   structural scenarios  valid, distinct integer horizons nearest the current
#                         horizon
#
# A range that cannot be formed inside the domain is reported with R's own
# sentence (`range_status` "unavailable" and `range_note`). It is never invented,
# never silently dropped, and never narrowed to a zero-width span.
EQALB_OWSA_RANGE_NOTE <- paste(
  "Default ranges follow the current base-case assumptions: each one is an",
  "illustrative model scenario built around the value that parameter has in this",
  "scenario, not an evidence-based uncertainty interval."
)

# --- Shared value helpers ----------------------------------------------------
#
# Small readers and formatters used by the interpretation below. They contain no
# economics of their own: they read what R already computed and turn it into the
# one sentence each value belongs in.

# The model's decision rule at the willingness-to-pay threshold being analysed:
# incremental net monetary benefit at or above zero. Defined once, so the scenario
# rows, the base case and the interpretation cannot disagree about it.
eqalb_owsa_cost_effective <- function(inmb) {
  value <- suppressWarnings(as.numeric(inmb))
  value[!is.finite(value)] <- NA_real_
  value >= 0
}

# One attribute of a result frame as a single value, with a default when the frame
# does not carry it (the Shiny tab supplies fewer attributes than the API frame).
eqalb_owsa_attr_value <- function(result, name, default) {
  value <- attr(result, name)
  if (is.null(value) || length(value) == 0L) return(default)
  value[[1]]
}

# One value as a single finite number, or NA. Nothing is printed that could not be
# read as a number.
eqalb_owsa_number <- function(value) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    return(NA_real_)
  }
  value
}

# A published outcome label as it reads inside a sentence: unchanged when it is an
# acronym (ICER), otherwise lower-cased at the first letter.
eqalb_owsa_mid_sentence <- function(label) {
  if (!nzchar(label) || toupper(label) == label) return(label)
  paste0(tolower(substr(label, 1, 1)), substr(label, 2, nchar(label)))
}

# A list of names as one readable phrase: "A", "A and B", "A, B and C".
eqalb_owsa_sentence_list <- function(values) {
  if (length(values) == 0L) return("")
  if (length(values) == 1L) return(values[[1]])
  paste0(paste(values[-length(values)], collapse = ", "), " and ", values[[length(values)]])
}

# One value of the selected outcome, formatted the way that outcome is read
# everywhere else: money rounded to whole euro for the cost, net-benefit and ICER
# rankings, four decimals for QALYs.
eqalb_owsa_format_selected <- function(value, outcome) {
  value <- eqalb_owsa_number(value)
  if (!is.finite(value)) return("not available")
  if (identical(outcome, "incremental_qalys")) {
    return(format(round(value, 4), nsmall = 4, big.mark = ",", scientific = FALSE))
  }
  paste0("\u20ac", format(round(value), big.mark = ",", scientific = FALSE))
}

# The state an active range is in. R decides this by comparing the active values
# with the values its own policy derives, so a caller never classifies a range.
EQALB_OWSA_RANGE_DEFAULT_STATE <- "Model default"
EQALB_OWSA_RANGE_ADJUSTED_STATE <- "Adjusted"

# Absolute widths for the frozen-width parameters. The model's own default
# scenario plus these offsets reproduces the ranges the application has shown
# since the first release, so the policy change does not change the default
# analysis.
eqalb_owsa_frozen_widths <- function() {
  data.frame(
    id = c(
      "intervention_price", "implementation_cost", "healthcare_savings", "rrr",
      "engagement_year1", "engagement_followup", "utility_no_event",
      "utility_post_mi", "utility_post_stroke", "cost_post_mi",
      "cost_post_stroke"
    ),
    low_offset = c(
      -180, -40, -20, -0.05, -0.20, -0.22, -0.06, -0.10, -0.15, -4315, -4677
    ),
    high_offset = c(
      180, 60, 40, 0.05, 0.15, 0.18, 0.06, 0.10, 0.15, 5685, 5323
    ),
    stringsAsFactors = FALSE
  )
}

# One row per OWSA parameter: what it is, where it is shown, how its range is
# derived, the domain an override has to stay inside, and the wording that
# explains the range. The permitted domain is the one the model interface
# publishes for the input (`parameter_specs()` in api/plumber.R), except for the
# two event-cost anchors, which the model itself accepts with no upper bound and
# which therefore use the same cost cap the other cost inputs use.
eqalb_owsa_range_specs <- function() {
  data.frame(
    id = c(
      "intervention_price", "implementation_cost", "healthcare_savings", "rrr",
      "engagement_year1", "engagement_followup", "utility_no_event",
      "utility_post_mi", "utility_post_stroke", "cost_post_mi",
      "cost_post_stroke", "discount_rate_cost", "discount_rate_effect",
      "time_horizon"
    ),
    parameter = c(
      "Annual intervention price",
      "Implementation cost",
      "Annual healthcare-use savings",
      "Relative risk reduction among engaged users",
      "Year-1 engagement",
      "Follow-up engagement",
      "Utility: no prior cardiovascular event",
      "Utility: post-MI",
      "Utility: post-stroke",
      "Cost: post-MI (year-1 anchor)",
      "Cost: post-stroke (year-1 anchor)",
      "Cost discount rate",
      "Effect discount rate",
      "Time horizon"
    ),
    model_arg = c(
      "scenario_intervention_price", "scenario_implementation_cost",
      "scenario_healthcare_savings", "scenario_rrr",
      "scenario_engagement_year1", "scenario_engagement_followup",
      "scenario_utility_no_event", "scenario_utility_post_mi",
      "scenario_utility_post_stroke", "scenario_cost_post_mi_year1",
      "scenario_cost_post_stroke_year1", "scenario_discount_rate_cost",
      "scenario_discount_rate_effect", "scenario_cycles"
    ),
    group = c(
      "Intervention", "Intervention", "Intervention", "Clinical", "Clinical",
      "Clinical", "Utilities", "Utilities", "Utilities", "Event costs",
      "Event costs", "Discounting", "Discounting", "Time horizon"
    ),
    unit = c(
      "EUR per active user per year", "EUR per new user",
      "EUR per active user per year", "fraction (0-1)", "fraction (0-1)",
      "fraction (0-1)", "utility (0-1)", "utility (0-1)", "utility (0-1)",
      "EUR per person", "EUR per person", "fraction (0-1)", "fraction (0-1)",
      "years"
    ),
    range_mode = c(
      rep("frozen width", 11), "policy pair", "policy pair",
      "structural scenarios"
    ),
    range_source = c(
      "Illustrative contracting scenario", "Illustrative start-up scenario",
      "Illustrative utilisation scenario", "Illustrative clinical scenario",
      "Illustrative implementation scenario",
      "Illustrative implementation scenario", "Illustrative utility scenario",
      "Illustrative utility scenario", "Illustrative utility scenario",
      "Illustrative event-cost scenario", "Illustrative event-cost scenario",
      "Model discounting policy scenario", "Model discounting policy scenario",
      "Model structural scenario"
    ),
    range_rationale = c(
      paste(
        "Illustrative -EUR180/+EUR180 around the current annual price, floored",
        "at EUR0 and capped at EUR2,000: a contracting-variation scenario, not an",
        "evidence interval."
      ),
      paste(
        "Illustrative -EUR40/+EUR60 around the current one-off implementation",
        "cost, floored at EUR0: a start-up-cost scenario, not an evidence interval."
      ),
      paste(
        "Illustrative -EUR20/+EUR40 around the current annual healthcare-use",
        "savings, floored at EUR0: a utilisation scenario, not an evidence interval."
      ),
      paste(
        "Illustrative -0.05/+0.05 around the current relative risk reduction,",
        "kept inside the model's 0-0.30 clinical domain."
      ),
      paste(
        "Illustrative -0.20/+0.15 around the current year-1 engagement, clamped",
        "to 0-1."
      ),
      paste(
        "Illustrative -0.22/+0.18 around the current follow-up engagement,",
        "clamped to 0-1."
      ),
      "Illustrative -0.06/+0.06 around the current no-event utility, clamped to 0-1.",
      "Illustrative -0.10/+0.10 around the current post-MI utility, clamped to 0-1.",
      "Illustrative -0.15/+0.15 around the current post-stroke utility, clamped to 0-1.",
      paste(
        "Illustrative -EUR4,315/+EUR5,685 around the current post-MI year-1 cost",
        "anchor, floored at EUR0; the follow-up cost keeps its ratio to the anchor."
      ),
      paste(
        "Illustrative -EUR4,677/+EUR5,323 around the current post-stroke year-1",
        "cost anchor, floored at EUR0; the follow-up cost keeps its ratio to the",
        "anchor."
      ),
      paste(
        "Policy pair: no discounting and twice the current cost discount rate,",
        "kept inside the model's 0-0.10 domain."
      ),
      paste(
        "Policy pair: no discounting and twice the current effect discount rate,",
        "kept inside the model's 0-0.10 domain."
      ),
      paste(
        "Structural scenarios: the nearest valid, distinct whole-year horizons",
        "around the current horizon; at the edge of the permitted range they sit",
        "on one side of it."
      )
    ),
    min = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
    max = c(2000, 500, 500, 0.30, 1, 1, 1, 1, 1, 1e6, 1e6, 0.10, 0.10, 100),
    step = c(10, 5, 5, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 100, 100,
             0.005, 0.005, 1),
    integer = c(rep(FALSE, 13), TRUE),
    editable = rep(TRUE, 14),
    stringsAsFactors = FALSE
  )
}

# The model's own base-case value for every OWSA parameter, so a caller that has
# no scenario (the value-based price module, the standalone demo, a direct
# `run_eqalb_owsa(base_args = eqalb_owsa_base_args())`) can still read one canonical
# definition. The two follow-up event costs are included because the cost-anchor
# scenarios need them to keep their year-one-to-follow-up ratio.
eqalb_owsa_base_args <- function() {
  list(
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
  )
}

# One scenario value, as a single finite number or NA. A caller that omits a
# value, or sends something the model cannot use, gets NA rather than a guess.
eqalb_owsa_scenario_value <- function(base_args, model_arg) {
  value <- base_args[[model_arg]]
  if (is.null(value) || length(value) != 1L) return(NA_real_)
  value <- suppressWarnings(as.numeric(value))
  if (is.na(value) || !is.finite(value)) NA_real_ else value
}

# Valid, distinct whole-year horizon scenarios nearest the current horizon. The
# model's own first choice is the pair the application has always used, five
# years below and ten above; when that leaves the permitted domain the nearest
# pair that keeps both endpoints valid, whole and different from the current
# horizon is used. A pair that cannot be formed comes back as NA and is reported
# by the caller rather than invented.
eqalb_owsa_horizon_scenarios <- function(base_value, min_value, max_value) {
  base <- as.integer(base_value)
  offsets <- list(
    c(-5, 10), c(-10, 5), c(5, 10), c(-10, -5), c(-3, 3), c(-2, 2), c(2, 3),
    c(-3, -2), c(1, 2), c(-2, -1)
  )
  for (offset in offsets) {
    low <- base + offset[[1]]
    high <- base + offset[[2]]
    if (low >= min_value && high <= max_value && low < high &&
        low != base && high != base) {
      return(c(low = as.numeric(low), high = as.numeric(high)))
    }
  }
  c(low = NA_real_, high = NA_real_)
}

# Whether an active range is the model's own derived range for this scenario or
# one the caller supplied. R decides; a client renders the answer.
eqalb_owsa_range_state <- function(low, high, low_default, high_default) {
  same <- function(a, b) {
    if (!is.finite(a) && !is.finite(b)) return(TRUE)
    is.finite(a) && is.finite(b) && abs(a - b) <= 1e-9 * max(1, abs(b))
  }
  if (same(low, low_default) && same(high, high_default)) {
    EQALB_OWSA_RANGE_DEFAULT_STATE
  } else {
    EQALB_OWSA_RANGE_ADJUSTED_STATE
  }
}

# Validates one supplied range against the parameter's own domain. Returns "" when
# the range is structurally usable, or R's own sentence describing the rule it
# breaks. Only rules that make the range unusable are errors: a finite value, the
# parameter's domain, a low value below its high value, and whole years for the
# time horizon.
eqalb_owsa_override_error <- function(spec, low, high) {
  label <- spec$parameter[[1]]
  domain <- paste0(
    format(spec$min[[1]], digits = 6), " to ", format(spec$max[[1]], digits = 6)
  )
  if (spec$integer[[1]] && is.finite(low) && is.finite(high)) {
    if (low != round(low) || high != round(high)) {
      return(paste0("'", label, "': the time-horizon range must be whole years."))
    }
  }
  if (!is.finite(low) || !is.finite(high)) {
    return(paste0(
      "'", label, "': supply both a low and a high value as single finite numbers."
    ))
  }
  if (low < spec$min[[1]] || low > spec$max[[1]]) {
    return(paste0("'", label, "': the low range value must be within ", domain, "."))
  }
  if (high < spec$min[[1]] || high > spec$max[[1]]) {
    return(paste0("'", label, "': the high range value must be within ", domain, "."))
  }
  if (low >= high) {
    return(paste0(
      "'", label, "': the low range value must be below the high range value."
    ))
  }
  ""
}

# Whether a usable range still contains the value the scenario gives the
# parameter. Returning "" means it does. A range that does not is reported rather
# than rejected: a range is a scenario the caller owns, and it stays absolute when
# the scenario changes, so R says what it observes instead of quietly rebasing the
# range or refusing to analyse it. One-sided ranges are exactly what a structural
# scenario at the edge of its domain produces, and the tornado chart draws them.
eqalb_owsa_contains_warning <- function(spec, low, high, base_value) {
  if (!is.finite(base_value) || !is.finite(low) || !is.finite(high)) return("")
  if (low <= base_value && high >= base_value) return("")
  paste0(
    "'", spec$parameter[[1]], "': this range does not contain the scenario's own ",
    "value (", format(base_value, digits = 6), "), so the analysis varies it ",
    "away from that value rather than around it."
  )
}

# The derived range for every OWSA parameter in one scenario.
eqalb_owsa_range_defaults <- function(base_args) {
  specs <- eqalb_owsa_range_specs()
  widths <- eqalb_owsa_frozen_widths()

  rows <- lapply(seq_len(nrow(specs)), function(i) {
    spec <- specs[i, , drop = FALSE]
    base_value <- eqalb_owsa_scenario_value(base_args, spec$model_arg[[1]])
    low <- NA_real_
    high <- NA_real_
    status <- "ok"
    note <- ""
    warning <- ""

    if (!is.finite(base_value)) {
      status <- "unavailable"
      note <- paste0(
        "R has no value for ", spec$parameter[[1]], " in this scenario, so it ",
        "cannot derive an illustrative range for it."
      )
    } else if (identical(spec$range_mode[[1]], "frozen width")) {
      width <- widths[widths$id == spec$id[[1]], , drop = FALSE]
      low <- base_value + width$low_offset[[1]]
      high <- base_value + width$high_offset[[1]]
    } else if (identical(spec$range_mode[[1]], "policy pair")) {
      low <- 0
      high <- 2 * base_value
    } else {
      pair <- eqalb_owsa_horizon_scenarios(
        base_value, spec$min[[1]], spec$max[[1]]
      )
      low <- pair[["low"]]
      high <- pair[["high"]]
    }

    if (identical(status, "ok")) {
      if (spec$integer[[1]] && is.finite(low) && is.finite(high)) {
        low <- round(low)
        high <- round(high)
      }
      if (is.finite(low) && is.finite(high)) {
        low <- max(low, spec$min[[1]])
        high <- min(high, spec$max[[1]])
      }
      if (!is.finite(low) || !is.finite(high) || low >= high) {
        status <- "unavailable"
        note <- paste0(
          "R cannot derive a range for ", spec$parameter[[1]], " at ",
          format(base_value, digits = 6), " inside its permitted domain (",
          format(spec$min[[1]], digits = 6), " to ",
          format(spec$max[[1]], digits = 6), "). Set a range for it yourself to ",
          "keep it in the analysis."
        )
        low <- NA_real_
        high <- NA_real_
      } else if (low > base_value || high < base_value) {
        if (identical(spec$range_mode[[1]], "structural scenarios")) {
          # A structural scenario near the edge of its domain has to sit on one
          # side of the current horizon: there is no room both for a scenario
          # below it and one above it that differ from it. R reports that rather
          # than inventing a horizon the caller did not ask for.
          warning <- eqalb_owsa_contains_warning(spec, low, high, base_value)
        } else {
          status <- "unavailable"
          note <- paste0(
            "R cannot derive a range for ", spec$parameter[[1]],
            " that contains this scenario's own value (",
            format(base_value, digits = 6), ") inside its permitted domain. ",
            "Set a range for it yourself to keep it in the analysis."
          )
          low <- NA_real_
          high <- NA_real_
        }
      }
    }

    data.frame(
      id = spec$id,
      parameter = spec$parameter,
      model_arg = spec$model_arg,
      group = spec$group,
      unit = spec$unit,
      range_mode = spec$range_mode,
      range_source = spec$range_source,
      range_rationale = spec$range_rationale,
      min = spec$min,
      max = spec$max,
      step = spec$step,
      integer = spec$integer,
      editable = spec$editable,
      base_value = base_value,
      low_default = low,
      high_default = high,
      range_status = status,
      range_note = note,
      range_warning = warning,
      stringsAsFactors = FALSE
    )
  })

  table <- do.call(rbind, rows)
  rownames(table) <- NULL
  table
}

# Accepts the `bounds` block of a request in either shape jsonlite produces for a
# JSON array of objects, and returns one row per supplied range with `low`/`high`
# coerced to numbers (NA when a caller sends something that is not one, so the
# validator can report it).
eqalb_owsa_override_rows <- function(supplied) {
  if (is.null(supplied)) return(NULL)
  if (is.data.frame(supplied)) {
    rows <- supplied
  } else if (is.list(supplied) && length(supplied) > 0L) {
    rows <- do.call(rbind, lapply(supplied, function(entry) {
      if (!is.list(entry)) return(NULL)
      value_of <- function(name) {
        value <- entry[[name]]
        if (is.null(value) || length(value) == 0L) return(NULL)
        value[[1]]
      }
      data.frame(
        id = as.character(value_of("id")),
        low = suppressWarnings(as.numeric(value_of("low"))),
        high = suppressWarnings(as.numeric(value_of("high"))),
        stringsAsFactors = FALSE
      )
    }))
  } else {
    stop("Body 'bounds' must be a list of {id, low, high} rows.", call. = FALSE)
  }

  if (is.null(rows) || nrow(rows) == 0L) return(NULL)
  missing <- c("id", "low", "high")[!c("id", "low", "high") %in% names(rows)]
  if (length(missing) > 0L) {
    stop(
      "Body 'bounds' must contain id, low and high columns. Missing: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  data.frame(
    id = as.character(rows$id),
    low = suppressWarnings(as.numeric(rows$low)),
    high = suppressWarnings(as.numeric(rows$high)),
    stringsAsFactors = FALSE
  )
}

# The ranges in force for one request: R's derived default for every parameter,
# with any range the caller supplied replacing the row it names. `low`/`high` are
# the active values, `low_default`/`high_default` R's own values to compare
# against, and `range_state` R's verdict on the two.
#
# A supplied range that cannot be used is never dropped silently: its row keeps
# R's own sentence (range_status "invalid", range_note) and R's derived default as
# the active value. The analysis endpoint turns that into an error; the defaults
# endpoint returns it so an editor can show the caller what R requires. A usable
# range that no longer contains the scenario's own value stays active and carries
# R's observation in range_warning, because a range is a scenario the caller owns
# and it is never silently rebased.
eqalb_owsa_range_bounds <- function(base_args, supplied = NULL) {
  bounds <- eqalb_owsa_range_defaults(base_args)
  bounds$low <- bounds$low_default
  bounds$high <- bounds$high_default

  overrides <- eqalb_owsa_override_rows(supplied)
  if (!is.null(overrides)) {
    unknown <- setdiff(overrides$id, bounds$id)
    if (length(unknown) > 0L) {
      stop(
        "Body 'bounds' names an unknown OWSA parameter id: ",
        paste(unknown, collapse = ", "),
        call. = FALSE
      )
    }
    for (i in which(bounds$id %in% overrides$id)) {
      row <- overrides[overrides$id == bounds$id[[i]], , drop = FALSE]
      spec <- bounds[i, , drop = FALSE]
      note <- eqalb_owsa_override_error(spec, row$low[[1]], row$high[[1]])
      if (nzchar(note)) {
        bounds$range_status[[i]] <- "invalid"
        bounds$range_note[[i]] <- note
        bounds$range_warning[[i]] <- ""
        next
      }
      bounds$low[[i]] <- row$low[[1]]
      bounds$high[[i]] <- row$high[[1]]
      if (identical(bounds$range_status[[i]], "unavailable")) {
        bounds$range_status[[i]] <- "ok"
        bounds$range_note[[i]] <- ""
      }
      bounds$range_warning[[i]] <- eqalb_owsa_contains_warning(
        spec, row$low[[1]], row$high[[1]], bounds$base_value[[i]]
      )
    }
  }

  bounds$range_state <- vapply(
    seq_len(nrow(bounds)),
    function(i) {
      eqalb_owsa_range_state(
        bounds$low[[i]], bounds$high[[i]],
        bounds$low_default[[i]], bounds$high_default[[i]]
      )
    },
    character(1)
  )
  rownames(bounds) <- NULL
  bounds
}

# The canonical ranges evaluated at the model's own base-case constants, with no
# caller scenario: the fixed-assumption view the value-based price module and the
# standalone demo use. The analysis endpoints call eqalb_owsa_range_bounds()
# instead, which derives the ranges from the scenario being analysed.
eqalb_owsa_parameters <- function() {
  eqalb_owsa_range_defaults(eqalb_owsa_base_args())
}

eqalb_owsa_outcome_labels <- c(
  inmb = "Incremental net monetary benefit",
  icer = "ICER",
  incremental_cost = "Incremental costs",
  incremental_qalys = "Incremental QALYs"
)

eqalb_owsa_format_wtp <- function(value) {
  format(round(value), big.mark = ",", scientific = FALSE, trim = TRUE)
}

eqalb_owsa_selected_value <- function(result, outcome, wtp) {
  if (!isTRUE(result$valid)) return(NA_real_)
  switch(
    outcome,
    inmb = result$inmb,
    icer = result$icer,
    incremental_cost = result$incremental_cost,
    incremental_qalys = result$incremental_qalys,
    stop("Unknown OWSA outcome.", call. = FALSE)
  )
}

# Scenario execution: every low/high call reuses the complete production model.
# nolint start: object_usage_linter
eqalb_owsa_run_scenario <- function(parameter, value, base_args, wtp, outcome) {
  scenario_args <- base_args
  scenario_args[[parameter$model_arg]] <- value

  if (parameter$id == "cost_post_mi") {
    followup_ratio <- base_args$scenario_cost_post_mi_followup /
      base_args$scenario_cost_post_mi_year1
    scenario_args$scenario_cost_post_mi_followup <- value * followup_ratio
  } else if (parameter$id == "cost_post_stroke") {
    followup_ratio <- base_args$scenario_cost_post_stroke_followup /
      base_args$scenario_cost_post_stroke_year1
    scenario_args$scenario_cost_post_stroke_followup <- value * followup_ratio
  }

  tryCatch({
    result <- do.call(run_eqalb_model, scenario_args)
    incremental_cost <- result$incremental_cost
    incremental_qalys <- result$incremental_qalys
    if (!is.finite(incremental_cost) || !is.finite(incremental_qalys)) {
      stop("The model returned a non-finite incremental result.")
    }

    inmb <- incremental_qalys * wtp - incremental_cost
    icer_is_interpretable <- incremental_qalys > 0 && is.finite(result$icer)
    warning <- if (incremental_qalys < 0 && incremental_cost > 0) {
      "Dominated: higher cost and fewer QALYs; ICER not interpretable."
    } else if (incremental_qalys <= 0) {
      "Non-positive incremental QALYs; ICER not interpretable."
    } else {
      ""
    }

    list(
      valid = TRUE,
      incremental_cost = incremental_cost,
      incremental_qalys = incremental_qalys,
      icer = if (icer_is_interpretable) result$icer else NA_real_,
      inmb = inmb,
      cost_effective = eqalb_owsa_cost_effective(inmb),
      warning = warning
    )
  }, error = function(error) {
    list(
      valid = FALSE,
      incremental_cost = NA_real_,
      incremental_qalys = NA_real_,
      icer = NA_real_,
      inmb = NA_real_,
      cost_effective = NA,
      warning = paste("Model failed:", conditionMessage(error))
    )
  })
}

# OWSA calculation: compute the base case once, then run one low and one high
# scenario per parameter while holding all other model inputs fixed.
run_eqalb_owsa <- function(base_args, bounds, wtp, outcome) {
  base_result <- tryCatch(
    do.call(run_eqalb_model, base_args),
    error = function(error) stop(
      paste("Base-case model failed:", conditionMessage(error)),
      call. = FALSE
    )
  )
  base_values <- list(
    valid = TRUE,
    incremental_cost = base_result$incremental_cost,
    incremental_qalys = base_result$incremental_qalys,
    icer = if (base_result$incremental_qalys > 0) base_result$icer else NA_real_,
    inmb = base_result$incremental_qalys * wtp - base_result$incremental_cost
  )
  base_outcome <- eqalb_owsa_selected_value(base_values, outcome, wtp)
  if (!is.finite(base_outcome)) {
    stop("The selected base-case outcome is not interpretable.", call. = FALSE)
  }

  rows <- lapply(seq_len(nrow(bounds)), function(i) {
    parameter <- bounds[i, , drop = FALSE]
    base_value <- eqalb_owsa_scenario_value(base_args, parameter$model_arg[[1]])
    unavailable <- !is.null(parameter$range_status) &&
      !identical(parameter$range_status[[1]], "ok")
    if (unavailable) {
      # R could not derive a usable range for this parameter in this scenario, or
      # the caller's replacement for it broke a rule before the endpoint rejected
      # the request. The parameter stays in the table carrying R's own sentence
      # and no numbers, so it is reported rather than silently dropped; the
      # ranking leaves it out because it has no range to rank. No model run
      # happens for it, because there is no scenario to run.
      note <- parameter$range_note
      note <- if (is.null(note) || length(note) == 0L) "" else note[[1]]
      reported <- list(
        valid = FALSE,
        incremental_cost = NA_real_,
        incremental_qalys = NA_real_,
        icer = NA_real_,
        inmb = NA_real_,
        cost_effective = NA,
        warning = note
      )
      low <- reported
      high <- reported
    } else {
      low <- eqalb_owsa_run_scenario(
        parameter, parameter$low, base_args, wtp, outcome
      )
      high <- eqalb_owsa_run_scenario(
        parameter, parameter$high, base_args, wtp, outcome
      )
    }
    selected_low <- eqalb_owsa_selected_value(low, outcome, wtp)
    selected_high <- eqalb_owsa_selected_value(high, outcome, wtp)
    impact <- if (is.finite(selected_low) && is.finite(selected_high)) {
      abs(selected_high - selected_low)
    } else {
      NA_real_
    }

    data.frame(
      parameter = parameter$parameter,
      parameter_id = parameter$id,
      base_value = base_value,
      low_value = parameter$low,
      high_value = parameter$high,
      low_incremental_cost = low$incremental_cost,
      high_incremental_cost = high$incremental_cost,
      low_incremental_qalys = low$incremental_qalys,
      high_incremental_qalys = high$incremental_qalys,
      low_icer = low$icer,
      high_icer = high$icer,
      low_inmb = low$inmb,
      high_inmb = high$inmb,
      selected_outcome_low = selected_low,
      selected_outcome_high = selected_high,
      impact_range = impact,
      low_cost_effective = low$cost_effective,
      high_cost_effective = high$cost_effective,
      low_warning = low$warning,
      high_warning = high$warning,
      stringsAsFactors = FALSE
    )
  })

  table <- do.call(rbind, rows)
  table <- table[order(table$impact_range, decreasing = TRUE, na.last = TRUE), ]
  rownames(table) <- NULL

  list(
    table = table,
    base = base_values,
    base_outcome = base_outcome,
    wtp = wtp,
    outcome = outcome,
    outcome_label = unname(eqalb_owsa_outcome_labels[[outcome]])
  )
}
# nolint end: object_usage_linter

eqalb_owsa_format_icer <- function(icer, incremental_cost, incremental_qalys) {
  if (incremental_qalys < 0 && incremental_cost > 0) return("Dominated")
  if (!is.finite(icer)) return("ICER not interpretable")
  format(round(icer, 2), big.mark = ",", nsmall = 2)
}

# Plain-language interpretation of a one-way analysis, shown in the closed
# "How to interpret this result" disclosure. Moved out of app.R's
# output$owsa_summary so the Shiny tab and the API render one implementation of the
# wording; no sentence is composed anywhere else.
#
# The interpretation states, in order:
#   1. the base case and the decision reference it is read against,
#   2. the two or three parameters whose tested range moves the selected outcome
#      most,
#   3. whether the decision survives the tested ranges,
#   4. any parameter the run could not vary,
#   5. the one-way limitation.
#
# `result` is a per-scenario frame: one row per parameter and scenario with
# `parameter`, `scenario`, `inmb`, `error_message` and `impact`, plus attributes.
# eqalb_owsa_scenario_rows() builds it for the API with the selected outcome, R's
# own cost-effectiveness flag per scenario and the outcome attributes the
# interpretation reads; the Shiny tab builds the same shape with `inmb` and the
# `base_inmb`/`wtp` attributes, which the reading below falls back to. Every number
# and every classification is R's: the ranking is R's `impact`, the decision is R's
# own cost-effectiveness rule, and no caller interprets anything.
summarize_eqalb_owsa <- function(result) {
  outcome <- as.character(eqalb_owsa_attr_value(result, "outcome", "inmb"))
  outcome_label <- as.character(eqalb_owsa_attr_value(result, "outcome_label", ""))
  if (!nzchar(outcome_label) || is.na(outcome_label)) {
    outcome_label <- unname(eqalb_owsa_outcome_labels[[outcome]])
  }
  if (is.null(outcome_label) || is.na(outcome_label) || !nzchar(outcome_label)) {
    outcome_label <- "incremental net monetary benefit"
  }
  outcome_mid <- eqalb_owsa_mid_sentence(outcome_label)

  wtp <- eqalb_owsa_number(eqalb_owsa_attr_value(result, "wtp", NA_real_))
  base_inmb <- eqalb_owsa_number(eqalb_owsa_attr_value(result, "base_inmb", NA_real_))
  base_selected <- eqalb_owsa_number(
    eqalb_owsa_attr_value(result, "base_outcome", base_inmb)
  )
  if (!is.finite(base_selected)) base_selected <- base_inmb
  threshold_text <- if (is.finite(wtp)) {
    paste0("\u20ac", eqalb_owsa_format_wtp(wtp), "/QALY")
  } else {
    "the selected willingness-to-pay threshold"
  }
  comparable <- is.finite(base_selected) && is.finite(wtp)
  base_is_cost_effective <- is.finite(base_inmb) && base_inmb >= 0

  # --- 1. The base case and the decision reference -----------------------------
  base_line <- if (identical(outcome, "inmb")) {
    if (comparable) {
      paste0(
        "Base-case incremental net monetary benefit: ",
        eqalb_owsa_format_selected(base_selected, outcome),
        " at the selected willingness-to-pay threshold of ", threshold_text, ", ",
        if (base_is_cost_effective) "above \u20ac0" else "below \u20ac0",
        ", so the base case is ",
        if (base_is_cost_effective) "cost effective" else "not cost effective", "."
      )
    } else {
      paste0(
        "The base-case incremental net monetary benefit is not available at ",
        threshold_text, ", so the decision reference cannot be stated."
      )
    }
  } else if (identical(outcome, "icer")) {
    if (comparable) {
      above_reference <- base_selected > wtp
      paste0(
        "Base-case ICER: ", eqalb_owsa_format_selected(base_selected, outcome),
        "/QALY vs reference threshold ", threshold_text, ", ",
        if (above_reference) "above" else "below",
        " the reference threshold, so the base case is ",
        if (above_reference) "not cost effective" else "cost effective", "."
      )
    } else {
      paste0(
        "The base-case ICER is not interpretable at this scenario, so the ",
        "decision reference cannot be stated."
      )
    }
  } else if (comparable) {
    # Incremental cost and incremental QALYs are ranked here, but the decision
    # reference is still the threshold comparison every other tab uses.
    paste0(
      "Base-case ", outcome_mid, ": ",
      eqalb_owsa_format_selected(base_selected, outcome),
      ". The decision reference is the incremental net monetary benefit at the ",
      "selected willingness-to-pay threshold of ", threshold_text, ": ",
      eqalb_owsa_format_selected(base_inmb, "inmb"), ", ",
      if (base_is_cost_effective) "above \u20ac0" else "below \u20ac0",
      ", so the base case is ",
      if (base_is_cost_effective) "cost effective" else "not cost effective", "."
    )
  } else {
    paste0(
      "The base-case ", outcome_mid, " is not available, so the decision ",
      "reference cannot be stated."
    )
  }

  # --- 2 and 3. The largest movers and whether the decision survives ----------
  impact_by_parameter <- tapply(result$impact, result$parameter, function(x) x[[1]])
  ranked <- names(sort(impact_by_parameter, decreasing = TRUE, na.last = TRUE))
  ranked <- ranked[is.finite(impact_by_parameter[ranked])]
  drivers <- utils::head(ranked, 3L)

  # R's own cost-effectiveness flag per scenario decides whether a parameter moves
  # the decision; the INMB sign is the same rule and is what the Shiny frame
  # carries.
  scenario_flag <- function(rows, scenario) {
    chosen <- rows[rows$scenario == scenario, , drop = FALSE]
    if (nrow(chosen) == 0L) return(NA)
    if ("cost_effective" %in% names(chosen)) return(chosen$cost_effective[[1]])
    as.logical(eqalb_owsa_cost_effective(chosen$inmb[[1]]))
  }
  decision_moves <- vapply(ranked, function(parameter) {
    rows <- result[result$parameter == parameter, , drop = FALSE]
    low <- scenario_flag(rows, "Low")
    high <- scenario_flag(rows, "High")
    if (is.na(low) || is.na(high)) return(FALSE)
    !identical(low, high)
  }, logical(1))
  sensitive <- ranked[decision_moves]

  # --- 4. Parameters the run could not vary -----------------------------------
  unvaried <- unique(result$parameter[
    !is.na(result$error_message) & nzchar(result$error_message)
  ])

  lines <- c(
    base_line,
    vapply(drivers, function(parameter) {
      paste0(
        parameter, " produces one of the largest movements in ", outcome_mid,
        " across its tested range."
      )
    }, character(1)),
    if (length(sensitive) > 0L) {
      paste0(
        "The conclusion is sensitive to the tested range of ",
        eqalb_owsa_sentence_list(sensitive), "."
      )
    } else if (length(ranked) > 0L) {
      "The conclusion remains unchanged across the tested one-way scenarios."
    } else {
      paste0(
        "No parameter could be varied in this run, so the robustness of the ",
        "conclusion was not tested."
      )
    },
    if (length(unvaried) > 0L) {
      paste0("Not varied in this run: ", eqalb_owsa_sentence_list(unvaried), ".")
    },
    "One-way analysis varies one parameter at a time; it does not represent joint parameter uncertainty."
  )
  paste(lines, collapse = "\n")
}

# The Shiny tab ranks by the INMB range and holds one row per scenario; the module
# holds one row per parameter with the low and high results in columns. This
# presents a run_eqalb_owsa() result in the shape summarize_eqalb_owsa() reads, so
# the interpretation has exactly one implementation for both callers.
#
# Beyond the columns the Shiny frame carries, this shape also holds the selected
# outcome at each scenario, R's own cost-effectiveness flag for each scenario (the
# rule the robustness sentence reads), and the attributes the interpretation needs:
# which outcome was ranked, its label, the base-case value of that outcome and
# whether the base case is cost effective. A scenario that failed has non-finite
# values (the module requires finite values of a successful run) and R's own
# sentence in `error_message`, which the interpretation reports as "not varied".
eqalb_owsa_scenario_rows <- function(result) {
  table <- result$table
  impact <- table$impact_range
  rows <- rbind(
    data.frame(
      parameter = table$parameter,
      scenario = "Low",
      inmb = table$low_inmb,
      selected = table$selected_outcome_low,
      cost_effective = table$low_cost_effective,
      error_message = ifelse(
        is.na(table$selected_outcome_low), table$low_warning, ""
      ),
      impact = impact,
      stringsAsFactors = FALSE
    ),
    data.frame(
      parameter = table$parameter,
      scenario = "High",
      inmb = table$high_inmb,
      selected = table$selected_outcome_high,
      cost_effective = table$high_cost_effective,
      error_message = ifelse(
        is.na(table$selected_outcome_high), table$high_warning, ""
      ),
      impact = impact,
      stringsAsFactors = FALSE
    )
  )
  rows <- rows[order(rows$impact, decreasing = TRUE, na.last = TRUE), , drop = FALSE]
  rownames(rows) <- NULL
  attr(rows, "base_inmb") <- result$base$inmb
  attr(rows, "wtp") <- result$wtp
  attr(rows, "outcome") <- result$outcome
  attr(rows, "outcome_label") <- result$outcome_label
  attr(rows, "base_outcome") <- result$base_outcome
  attr(rows, "base_cost_effective") <- eqalb_owsa_cost_effective(result$base$inmb)
  rows
}

# Data reshaping: keep invalid ICER scenarios out of the numeric tornado while
# retaining their warning and numeric NAs in the full results table.
eqalb_owsa_tornado_data <- function(result) {
  table <- result$table
  valid <- is.finite(table$selected_outcome_low) &
    is.finite(table$selected_outcome_high) &
    is.finite(table$impact_range)
  plot_data <- table[valid, , drop = FALSE]
  plot_data <- plot_data[order(plot_data$impact_range, decreasing = TRUE), , drop = FALSE]
  plot_data$parameter <- factor(plot_data$parameter, levels = rev(plot_data$parameter))
  plot_data$base_outcome <- result$base_outcome
  plot_data$low_hover <- vapply(seq_len(nrow(plot_data)), function(i) {
    row <- plot_data[i, ]
    paste0(
      "<b>", row$parameter, " - low input</b><br>",
      "Base: ", signif(row$base_value, 5), "<br>",
      "Low: ", signif(row$low_value, 5), "<br>",
      "High: ", signif(row$high_value, 5), "<br>",
      "Low ICER: ", eqalb_owsa_format_icer(
        row$low_icer, row$low_incremental_cost, row$low_incremental_qalys
      ), "<br>",
      "High ICER: ", eqalb_owsa_format_icer(
        row$high_icer, row$high_incremental_cost, row$high_incremental_qalys
      ), "<br>",
      "Low INMB: ", format(round(row$low_inmb, 2), big.mark = ","), "<br>",
      "High INMB: ", format(round(row$high_inmb, 2), big.mark = ","), "<br>",
      "Low cost-effective: ", row$low_cost_effective, "<br>",
      "High cost-effective: ", row$high_cost_effective
    )
  }, character(1))
  plot_data$high_hover <- sub("low input", "high input", plot_data$low_hover, fixed = TRUE)
  plot_data
}

# Plotting: interactive Plotly tornado; downloadable static image uses the same
# ranked low/high results and base reference line.
eqalb_owsa_plotly <- function(result) {
  plot_data <- eqalb_owsa_tornado_data(result)
  if (nrow(plot_data) == 0L) return(NULL)

  plotly::plot_ly() |>
    plotly::add_segments(
      data = plot_data,
      x = ~base_outcome, xend = ~selected_outcome_low,
      y = ~parameter, yend = ~parameter,
      text = ~low_hover, hoverinfo = "text",
      line = list(color = "#2F6DB0", width = 8), name = "Low parameter value"
    ) |>
    plotly::add_segments(
      data = plot_data,
      x = ~base_outcome, xend = ~selected_outcome_high,
      y = ~parameter, yend = ~parameter,
      text = ~high_hover, hoverinfo = "text",
      line = list(color = "#E68613", width = 8), name = "High parameter value"
    ) |>
    plotly::add_markers(
      data = plot_data,
      x = ~selected_outcome_low, y = ~parameter,
      text = ~low_hover, hoverinfo = "text",
      marker = list(color = "#2F6DB0", size = 9), name = "Low value"
    ) |>
    plotly::add_markers(
      data = plot_data,
      x = ~selected_outcome_high, y = ~parameter,
      text = ~high_hover, hoverinfo = "text",
      marker = list(color = "#E68613", size = 9), name = "High value"
    ) |>
    plotly::layout(
      title = paste0(
        "eQalb OWSA: ", result$outcome_label,
        " (WTP €", eqalb_owsa_format_wtp(result$wtp), "/QALY)"
      ),
      xaxis = list(title = result$outcome_label, zeroline = TRUE),
      yaxis = list(
        title = "Parameter",
        categoryorder = "array",
        categoryarray = as.character(plot_data$parameter)
      ),
      shapes = list(list(
        type = "line", xref = "x", yref = "paper",
        x0 = result$base_outcome, x1 = result$base_outcome, y0 = 0, y1 = 1,
        line = list(color = "black", dash = "dash", width = 2)
      )),
      annotations = list(list(
        x = result$base_outcome, xref = "x", y = 1, yref = "paper",
        text = "Base case", showarrow = FALSE, yanchor = "bottom"
      )),
      margin = list(l = 200, r = 30, b = 70, t = 90),
      legend = list(orientation = "h", x = 0, y = -0.18),
      hovermode = "closest"
    )
}

# nolint start: object_usage_linter
eqalb_owsa_ggplot <- function(result) {
  plot_data <- eqalb_owsa_tornado_data(result)
  if (nrow(plot_data) == 0L) return(NULL)
  long_data <- rbind(
    data.frame(parameter = plot_data$parameter,
               value = plot_data$selected_outcome_low, bound = "Low parameter value"),
    data.frame(parameter = plot_data$parameter,
               value = plot_data$selected_outcome_high, bound = "High parameter value")
  )
  long_data$base_outcome <- result$base_outcome

  ggplot2::ggplot(long_data, ggplot2::aes(y = parameter)) +
    ggplot2::geom_vline(xintercept = result$base_outcome, linetype = "dashed") +
    ggplot2::geom_segment(
      ggplot2::aes(x = base_outcome, xend = value, yend = parameter, colour = bound),
      linewidth = 4, lineend = "round", position = ggplot2::position_dodge(width = 0.5)
    ) +
    ggplot2::geom_point(
      ggplot2::aes(x = value, colour = bound), size = 2.5,
      position = ggplot2::position_dodge(width = 0.5)
    ) +
    ggplot2::scale_colour_manual(values = c(
      "Low parameter value" = "#2F6DB0", "High parameter value" = "#E68613"
    )) +
    ggplot2::labs(
      title = paste0(
        "eQalb OWSA: ", result$outcome_label,
        " (WTP €", eqalb_owsa_format_wtp(result$wtp), "/QALY)"
      ),
      subtitle = "Base case shown as a dashed black reference line",
      x = result$outcome_label, y = NULL, colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}
  # nolint end: object_usage_linter
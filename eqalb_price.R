# eQalb value-based price analysis.
#
# A reusable analysis module, sourced by api/plumber.R (and available to any
# other caller that sources the model modules), so the value-based price rules
# exist exactly once. It answers one payer question: how much can be paid per
# treated person per year for eQalb (charged for each year a treated person is
# alive) and still reach the reference willingness-to-pay threshold?
#
# Every figure is computed from run_eqalb_model() (eqalb_markov.R) outputs. The
# module contains no economics of its own: it solves for the annual intervention
# price at which the model's own incremental cost and QALYs give an incremental
# net monetary benefit of zero, and it re-runs the model at that price to verify
# the answer. The two scan axes reuse the model's existing relative-risk-reduction
# and year-1 engagement bounds from eqalb_owsa_parameters() (eqalb_owsa.R), so no
# new clinical or economic assumption is introduced.
#
# All status bands, grid levels, labels and interpretation sentences are defined
# here, so no caller composes or rewords them. The thresholds and status bands
# are illustrative teaching rules for the fictional eQalb digital therapeutic;
# they are not a validated pricing, reimbursement or HTA standard.

# --- Constants ---------------------------------------------------------------

# Distance in EUR per treated person per year between the two model runs the price
# solve uses. The model's incremental cost is linear in the annual intervention
# price, so any positive step works; this value only sets the numerical scale of
# the slope.
EQALB_PRICE_PROBE_STEP <- 100

# The solved price is verified by a model run at that price, which must return an
# incremental net monetary benefit within this many EUR of zero. Without it the
# solution is replaced by a bisection search.
EQALB_PRICE_VERIFY_TOLERANCE <- 0.01

# Upper bound of the price search. It mirrors the model API's own bound on the
# annual intervention price (scenario_args() in api/plumber.R rejects a larger
# value), so a supported price beyond it is reported as not identifiable instead
# of as a number the endpoint could not accept back.
EQALB_PRICE_MAX_PRICE <- 1e6

# Search interval for the required relative risk reduction: the model's own
# validated domain for that input (0 to 1). A requirement outside this interval
# is reported as not identifiable rather than guessed.
EQALB_PRICE_RRR_MIN <- 0
EQALB_PRICE_RRR_MAX <- 1
# Bisection precision for the required relative risk reduction, in the fraction
# itself (0.001 is one tenth of a percentage point).
EQALB_PRICE_RRR_TOLERANCE <- 0.001
# Iteration cap, so a pathological model response cannot loop forever.
EQALB_PRICE_MAX_ITERATIONS <- 40L

# Status bands. Green: the current annual price is supported at the reference
# threshold. Red: it is not. Not available: the model did not return the values
# the comparison needs.
EQALB_PRICE_STATUS_GREEN <- "Green"
EQALB_PRICE_STATUS_RED <- "Red"
EQALB_PRICE_STATUS_NOT_AVAILABLE <- "Not available"

# The two assumptions the 3 x 3 scan varies, named by their bound id in
# eqalb_owsa_parameters().
EQALB_PRICE_GRID_AXES <- c("rrr", "engagement_year1")

EQALB_PRICE_METHOD_NOTE <- paste(
  "The maximum acceptable price is solved from the model's own outputs:",
  "incremental cost is a straight line in the annual intervention price, so two",
  "model runs give its slope and level, and the price at which incremental net",
  "monetary benefit is zero follows directly. R then re-runs the model at that",
  "price and requires the incremental net monetary benefit to be within",
  paste0("\u20ac", format(EQALB_PRICE_VERIFY_TOLERANCE, nsmall = 2)),
  "of zero; if it is not, a bisection search replaces the solved value.",
  "The required relative risk reduction is found by bisection and its final run",
  "verifies the reported value. One-way analysis: each figure varies one",
  "assumption at a time and does not represent joint uncertainty."
)

# The qualification the interface shows with the results. It is deliberately
# separate from the method note above: the note describes how the numbers are
# produced (for a caller reading the API or the exported package), while this
# sentence states what the numbers do not cover, which is part of reading them.
EQALB_PRICE_LIMITATION <- paste(
  "Illustrative one-way analysis: the maximum acceptable price and the required",
  "relative risk reduction each vary one assumption at a time, so neither",
  "represents joint uncertainty across the model's inputs."
)

# The required-effect verdict named for the interface. `verdict` stays the
# machine-readable value the API and the exported package use; `verdict_label` is
# the same state in words, decided here so no caller maps it.
EQALB_PRICE_VERDICT_LABELS <- c(
  met = "Met",
  not_met = "Not met",
  not_available = "Not available"
)

eqalb_price_verdict_label <- function(verdict) {
  if (length(verdict) != 1L || is.na(verdict)) {
    return("Not available")
  }
  label <- unname(EQALB_PRICE_VERDICT_LABELS[verdict])
  if (is.na(label)) "Not available" else label
}

# --- Formatting --------------------------------------------------------------

eqalb_price_format_money <- function(value) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    return("\u2014")
  }
  paste0(
    "\u20ac",
    format(
      round(value, 2),
      big.mark = ",", nsmall = 2, scientific = FALSE, trim = TRUE
    )
  )
}

eqalb_price_format_money_signed <- function(value) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    return("\u2014")
  }
  formatted <- paste0(
    "\u20ac",
    format(
      round(abs(value), 2),
      big.mark = ",", nsmall = 2, scientific = FALSE, trim = TRUE
    )
  )
  if (value < 0) paste0("-", formatted) else formatted
}

eqalb_price_format_percent <- function(value, digits = 1) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    return("\u2014")
  }
  paste0(
    format(
      round(value, digits),
      nsmall = digits, scientific = FALSE, trim = TRUE, drop0trailing = TRUE
    ),
    "%"
  )
}

# Percentages of the scan levels, without trailing zeros (5%, 10%, 42%).
eqalb_price_format_share <- function(value) {
  eqalb_price_format_percent(value * 100, digits = 2)
}

# Willingness-to-pay thresholds are quoted in whole euros, the convention the
# rest of the app uses ("€100,000 per QALY").
eqalb_price_format_threshold <- function(value) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    return("\u2014")
  }
  paste0(
    "\u20ac",
    format(round(value), big.mark = ",", scientific = FALSE, trim = TRUE),
    " per QALY"
  )
}

# --- Model runs --------------------------------------------------------------

# Runs the model once and returns the incremental values the analysis reads.
# `price` overrides the annual intervention price; `rrr` and `engagement_year1`
# override the two scan assumptions when they are supplied. A failure is
# returned, not thrown, so one failing grid cell cannot fail the whole analysis.
eqalb_price_run <- function(base_args, price, rrr = NULL,
                            engagement_year1 = NULL) {
  args <- base_args
  args$scenario_intervention_price <- price
  if (!is.null(rrr)) args$scenario_rrr <- rrr
  if (!is.null(engagement_year1)) {
    args$scenario_engagement_year1 <- engagement_year1
  }

  tryCatch(
    {
      result <- suppressMessages(do.call(run_eqalb_model, args))
      incremental_cost <- result$incremental_cost
      incremental_qalys <- result$incremental_qalys
      if (!is.finite(incremental_cost) || !is.finite(incremental_qalys)) {
        stop("The model returned a non-finite incremental result.", call. = FALSE)
      }
      list(
        ok = TRUE,
        price = price,
        incremental_cost = incremental_cost,
        incremental_qalys = incremental_qalys,
        icer = if (incremental_qalys > 0) {
          incremental_cost / incremental_qalys
        } else {
          NA_real_
        },
        price_cost_contribution = unname(
          result$components[["cost_intervention"]]
        ),
        message = ""
      )
    },
    error = function(error) {
      list(
        ok = FALSE,
        price = price,
        incremental_cost = NA_real_,
        incremental_qalys = NA_real_,
        icer = NA_real_,
        price_cost_contribution = NA_real_,
        message = conditionMessage(error)
      )
    }
  )
}

eqalb_price_nmb <- function(run, wtp) {
  wtp * run$incremental_qalys - run$incremental_cost
}

# --- Price solve -------------------------------------------------------------

# The not-identifiable result of one scenario. Every field is present, so a
# client never has to handle a missing key.
eqalb_price_unavailable <- function(reason, method = "not_available",
                                    run = NULL, wtp = NA_real_) {
  run_ok <- !is.null(run) && isTRUE(run$ok)
  nmb <- if (run_ok && is.finite(wtp)) eqalb_price_nmb(run, wtp) else NA_real_
  list(
    available = FALSE,
    method = method,
    max_acceptable_price = NA_real_,
    solved_price = NA_real_,
    verified = NA,
    verification_nmb = NA_real_,
    price_cost_slope = NA_real_,
    cost_without_price = NA_real_,
    incremental_cost = if (run_ok) run$incremental_cost else NA_real_,
    incremental_qalys = if (run_ok) run$incremental_qalys else NA_real_,
    icer = if (run_ok) run$icer else NA_real_,
    incremental_nmb = nmb,
    zero_price_nmb = NA_real_,
    price_supported = if (is.na(nmb)) NA else nmb >= 0,
    status = EQALB_PRICE_STATUS_NOT_AVAILABLE,
    reason = reason
  )
}

# Bisection fallback for the price solve. The model's incremental net monetary
# benefit is non-increasing in the annual intervention price (only the cost side
# changes with the price), so the highest price with a non-negative net monetary
# benefit is found by bisection, bounded by the model's own price bound.
eqalb_price_bisect <- function(base_args, wtp,
                               tolerance = EQALB_PRICE_VERIFY_TOLERANCE * 100) {
  zero_run <- eqalb_price_run(base_args, 0)
  if (!zero_run$ok) return(list(ok = FALSE, message = zero_run$message))

  upper <- min(EQALB_PRICE_MAX_PRICE, 1000)
  repeat {
    upper_run <- eqalb_price_run(base_args, upper)
    if (!upper_run$ok) return(list(ok = FALSE, message = upper_run$message))
    if (eqalb_price_nmb(upper_run, wtp) < 0) break
    if (upper >= EQALB_PRICE_MAX_PRICE) {
      # The threshold is not reached anywhere in the model's price domain.
      return(list(ok = TRUE, exists = TRUE, price = upper, run = upper_run))
    }
    upper <- min(EQALB_PRICE_MAX_PRICE, upper * 2)
  }

  if (eqalb_price_nmb(zero_run, wtp) < 0) {
    return(list(ok = TRUE, exists = FALSE, price = NA_real_, run = zero_run))
  }

  low <- 0
  low_run <- zero_run
  high <- upper
  for (iteration in seq_len(EQALB_PRICE_MAX_ITERATIONS)) {
    if (high - low <= tolerance) break
    mid <- (low + high) / 2
    mid_run <- eqalb_price_run(base_args, mid)
    if (!mid_run$ok) return(list(ok = FALSE, message = mid_run$message))
    if (eqalb_price_nmb(mid_run, wtp) >= 0) {
      low <- mid
      low_run <- mid_run
    } else {
      high <- mid
    }
  }
  list(ok = TRUE, exists = TRUE, price = low, run = low_run)
}

# Solves one scenario for the highest annual price that reaches the reference
# threshold. `run0` must be the model run at `current_price` with the scenario's
# other inputs; the result always carries every field, with NA for a value that
# could not be identified.
eqalb_price_solve <- function(base_args, wtp, current_price, run0) {
  if (!run0$ok) {
    return(eqalb_price_unavailable(
      paste0("The model did not run: ", run0$message),
      run = run0, wtp = wtp
    ))
  }

  nmb_at_current <- eqalb_price_nmb(run0, wtp)
  supported <- nmb_at_current >= 0
  status <- if (supported) {
    EQALB_PRICE_STATUS_GREEN
  } else {
    EQALB_PRICE_STATUS_RED
  }

  fill <- function(result) {
    result$incremental_cost <- run0$incremental_cost
    result$incremental_qalys <- run0$incremental_qalys
    result$icer <- run0$icer
    result$incremental_nmb <- nmb_at_current
    result$price_supported <- supported
    result$status <- status
    result
  }

  probe <- eqalb_price_run(base_args, current_price + EQALB_PRICE_PROBE_STEP)
  if (!probe$ok) {
    return(fill(eqalb_price_unavailable(
      paste0("The model did not run at the second price: ", probe$message),
      run = run0, wtp = wtp
    )))
  }

  qaly_change <- abs(probe$incremental_qalys - run0$incremental_qalys)
  slope <- (probe$incremental_cost - run0$incremental_cost) /
    EQALB_PRICE_PROBE_STEP
  cost_without_price <- run0$incremental_cost - slope * current_price
  solved <- if (is.finite(slope) && abs(slope) > 1e-9) {
    (wtp * run0$incremental_qalys - cost_without_price) / slope
  } else {
    NA_real_
  }

  base_available <- function(method, verified, verification_nmb) {
    list(
      available = TRUE,
      method = method,
      verified = verified,
      verification_nmb = verification_nmb,
      price_cost_slope = slope,
      cost_without_price = cost_without_price,
      zero_price_nmb = -cost_without_price,
      reason = ""
    )
  }

  # The affine solve is only usable when the model's cost really is a straight
  # line in the price and the price effect points the expected way. Otherwise the
  # bisection search, which makes no shape assumption, answers instead.
  if (!(run0$incremental_qalys > 0)) {
    return(fill(eqalb_price_unavailable(
      paste0(
        "Incremental QALYs are not positive (",
        format(run0$incremental_qalys, digits = 4, scientific = FALSE,
               trim = TRUE),
        "), so the price at which the threshold is reached is not identifiable."
      ),
      run = run0, wtp = wtp
    )))
  }
  if (!is.finite(slope) || slope <= 1e-9 || qaly_change > 1e-8) {
    bisected <- eqalb_price_bisect(base_args, wtp)
    if (!bisected$ok) {
      return(fill(eqalb_price_unavailable(
        paste0("The model did not run: ", bisected$message),
        run = run0, wtp = wtp
      )))
    }
    if (!bisected$exists) {
      return(fill(eqalb_price_unavailable(
        paste0(
          "No non-negative annual price reaches the reference threshold: the ",
          "model's incremental net monetary benefit is already below zero ",
          "before any price is added, and it falls as the price rises."
        ),
        method = "bisection_fallback",
        run = run0, wtp = wtp
      )))
    }
    return(fill(c(
      base_available(
        "bisection_fallback", TRUE, eqalb_price_nmb(bisected$run, wtp)
      ),
      list(
        max_acceptable_price = bisected$price,
        solved_price = bisected$price
      )
    )))
  }

  if (solved < 0) {
    result <- fill(eqalb_price_unavailable(
      paste0(
        "No non-negative annual price reaches the reference threshold: the ",
        "model's incremental net monetary benefit is already below zero before ",
        "any price is added, so no annual price at or above zero reaches it."
      ),
      run = run0, wtp = wtp
    ))
    # The raw root is kept on the result for an API caller, but it is no longer
    # quoted in the reason: the sentence a reader sees states the limitation
    # without the intermediate solve.
    result$solved_price <- solved
    return(result)
  }
  if (solved > EQALB_PRICE_MAX_PRICE) {
    result <- fill(eqalb_price_unavailable(
      paste0(
        "A maximum acceptable price is not reported: the annual price the model ",
        "would need is above ", eqalb_price_format_money(EQALB_PRICE_MAX_PRICE),
        " per treated person per year, the highest price this analysis accepts."
      ),
      run = run0, wtp = wtp
    ))
    result$solved_price <- solved
    return(result)
  }

  verification <- eqalb_price_run(base_args, solved)
  if (!verification$ok) {
    return(fill(eqalb_price_unavailable(
      paste0(
        "The model did not return a result, so a maximum acceptable price is ",
        "not identifiable. ", verification$message
      ),
      run = run0, wtp = wtp
    )))
  }
  verification_nmb <- eqalb_price_nmb(verification, wtp)
  if (abs(verification_nmb) > EQALB_PRICE_VERIFY_TOLERANCE) {
    # The model did not reproduce the straight-line cost response, so the solved
    # value is replaced by a shape-free bisection search.
    available <- base_available(
      "bisection_fallback", TRUE, verification_nmb
    )
    bisected <- eqalb_price_bisect(base_args, wtp)
    if (bisected$ok && bisected$exists) {
      available <- base_available(
        "bisection_fallback", TRUE, eqalb_price_nmb(bisected$run, wtp)
      )
      return(fill(c(available, list(
        max_acceptable_price = bisected$price,
        solved_price = bisected$price
      ))))
    }
    return(fill(eqalb_price_unavailable(
      paste0(
        "The model did not confirm the price it solved for, so a maximum ",
        "acceptable price is not identifiable."
      ),
      run = run0, wtp = wtp
    )))
  }

  fill(c(
    base_available("affine_price_solve_verified", TRUE, verification_nmb),
    list(max_acceptable_price = solved, solved_price = solved)
  ))
}

# --- Required relative risk reduction ----------------------------------------

# The relative risk reduction the current annual price would need for the
# scenario to reach the reference threshold. Net monetary benefit increases with
# the reduction (more events avoided means more QALYs and lower event costs), so
# the crossing point is unique and bisection is sound. The reported value is
# verified by the model run that produced it, and a requirement outside the
# model's validated domain is reported as not identifiable.
eqalb_price_required_rrr <- function(base_args, wtp, current_price,
                                     current_rrr, current_run) {
  verdict_at_current <- if (isTRUE(current_run$ok)) {
    if (eqalb_price_nmb(current_run, wtp) >= 0) "met" else "not_met"
  } else {
    NA_character_
  }
  unavailable <- function(verdict, reason) {
    list(
      available = FALSE,
      verdict = verdict,
      verdict_label = eqalb_price_verdict_label(verdict),
      required_rrr = NA_real_,
      required_rrr_pct = NA_real_,
      current_rrr = current_rrr,
      current_rrr_pct = 100 * current_rrr,
      within_sensitivity_range = NA,
      precision_rrr = NA_real_,
      verification_nmb = NA_real_,
      reason = reason
    )
  }

  run_low <- eqalb_price_run(base_args, current_price, rrr = EQALB_PRICE_RRR_MIN)
  if (!run_low$ok) {
    return(unavailable(
      "not_available",
      paste0("The model did not run: ", run_low$message)
    ))
  }
  nmb_low <- eqalb_price_nmb(run_low, wtp)
  if (nmb_low >= 0) {
    return(list(
      available = TRUE,
      verdict = "met",
      verdict_label = eqalb_price_verdict_label("met"),
      required_rrr = EQALB_PRICE_RRR_MIN,
      required_rrr_pct = 100 * EQALB_PRICE_RRR_MIN,
      current_rrr = current_rrr,
      current_rrr_pct = 100 * current_rrr,
      within_sensitivity_range = TRUE,
      precision_rrr = 0,
      verification_nmb = nmb_low,
      reason = ""
    ))
  }

  run_high <- eqalb_price_run(
    base_args, current_price, rrr = EQALB_PRICE_RRR_MAX
  )
  if (!run_high$ok) {
    return(unavailable(
      "not_available",
      paste0("The model did not run: ", run_high$message)
    ))
  }
  if (eqalb_price_nmb(run_high, wtp) < 0) {
    return(unavailable(
      "not_met",
      paste0(
        "Even a relative risk reduction of ",
        eqalb_price_format_share(EQALB_PRICE_RRR_MAX),
        " among engaged users does not reach the reference threshold at the ",
        "current annual price, so a required relative risk reduction is not ",
        "identifiable."
      )
    ))
  }

  low <- EQALB_PRICE_RRR_MIN
  high <- EQALB_PRICE_RRR_MAX
  high_run <- run_high
  for (iteration in seq_len(EQALB_PRICE_MAX_ITERATIONS)) {
    if (high - low <= EQALB_PRICE_RRR_TOLERANCE) break
    mid <- (low + high) / 2
    mid_run <- eqalb_price_run(base_args, current_price, rrr = mid)
    if (!mid_run$ok) {
      return(unavailable(
        "not_available",
        paste0("The model did not run: ", mid_run$message)
      ))
    }
    if (eqalb_price_nmb(mid_run, wtp) >= 0) {
      high <- mid
      high_run <- mid_run
    } else {
      low <- mid
    }
  }

  range <- eqalb_price_sensitivity_range()
  verdict <- if (is.na(verdict_at_current)) {
    if (current_rrr >= high) "met" else "not_met"
  } else {
    verdict_at_current
  }
  list(
    available = TRUE,
    verdict = verdict,
    verdict_label = eqalb_price_verdict_label(verdict),
    required_rrr = high,
    required_rrr_pct = 100 * high,
    current_rrr = current_rrr,
    current_rrr_pct = 100 * current_rrr,
    within_sensitivity_range = high >= range$low && high <= range$high,
    precision_rrr = high - low,
    verification_nmb = eqalb_price_nmb(high_run, wtp),
    reason = ""
  )
}

# The model's own one-way range for the relative risk reduction, read from the
# module that defines the sensitivity bounds, so the required effect can be
# compared with the range the sensitivity analysis explores.
eqalb_price_sensitivity_range <- function() {
  parameters <- eqalb_owsa_parameters()
  row <- parameters[parameters$id == "rrr", , drop = FALSE]
  list(low = row$low_default[[1]], high = row$high_default[[1]])
}

# --- Scan axes ---------------------------------------------------------------

# One axis of the 3 x 3 scan: the model's low bound, the scenario value and the
# model's high bound, deduplicated when the scenario value coincides with a
# bound, and labelled in R. `bound_id` is the id the assumption has in
# eqalb_owsa_parameters(), so the levels are the model's existing bounds rather
# than new assumptions.
eqalb_price_axis <- function(base_args, bound_id) {
  parameters <- eqalb_owsa_parameters()
  row <- parameters[parameters$id == bound_id, , drop = FALSE]
  if (nrow(row) != 1L) {
    stop(
      "No sensitivity bound is defined for '", bound_id, "'.",
      call. = FALSE
    )
  }
  model_arg <- row$model_arg[[1]]
  scenario_value <- base_args[[model_arg]]
  candidates <- list(
    list(value = row$low_default[[1]], role = "low bound"),
    list(value = scenario_value, role = "scenario"),
    list(value = row$high_default[[1]], role = "high bound")
  )

  seen <- list()
  for (candidate in candidates) {
    key <- format(candidate$value, digits = 15)
    if (is.null(seen[[key]])) {
      seen[[key]] <- candidate
    } else {
      seen[[key]]$role <- paste(seen[[key]]$role, candidate$role, sep = " and ")
    }
  }
  values <- vapply(seen, function(entry) entry$value, numeric(1))
  roles <- vapply(seen, function(entry) entry$role, character(1))
  labels <- vapply(
    seq_along(values),
    function(i) {
      paste0(
        eqalb_price_format_share(values[[i]]), " (", roles[[i]], ")"
      )
    },
    character(1)
  )

  list(
    id = bound_id,
    parameter = row$parameter[[1]],
    model_arg = model_arg,
    unit = "percent",
    scenario_value = scenario_value,
    levels = data.frame(
      value = values,
      role = roles,
      label = labels,
      stringsAsFactors = FALSE
    )
  )
}

# --- Grid --------------------------------------------------------------------

# The 3 x 3 illustrative scan: the maximum acceptable price under each pair of
# the model's relative-risk-reduction and year-1 engagement bounds. `solve_for`
# returns a cached solve per assumption pair, so the scenario pair is computed
# once and shared with the headline.
eqalb_price_grid <- function(base_args, wtp, current_price, row_axis, column_axis,
                             solve_for) {
  cells <- vector("list", nrow(row_axis$levels) * nrow(column_axis$levels))
  index <- 0L
  for (r in seq_len(nrow(row_axis$levels))) {
    for (c in seq_len(nrow(column_axis$levels))) {
      index <- index + 1L
      solved <- solve_for(
        row_axis$levels$value[[r]], column_axis$levels$value[[c]]
      )
      available <- isTRUE(solved$available)
      cells[[index]] <- data.frame(
        row_value = row_axis$levels$value[[r]],
        row_label = row_axis$levels$label[[r]],
        column_value = column_axis$levels$value[[c]],
        column_label = column_axis$levels$label[[c]],
        incremental_cost = solved$incremental_cost,
        incremental_qalys = solved$incremental_qalys,
        max_acceptable_price = solved$max_acceptable_price,
        solved_price = solved$solved_price,
        headroom_eur = if (available && is.finite(solved$max_acceptable_price)) {
          solved$max_acceptable_price - current_price
        } else {
          NA_real_
        },
        headroom_pct = if (available && is.finite(solved$max_acceptable_price) &&
          current_price > 0) {
          100 * (solved$max_acceptable_price - current_price) / current_price
        } else {
          NA_real_
        },
        price_supported = solved$price_supported,
        status = solved$status,
        available = available,
        warning = solved$reason,
        stringsAsFactors = FALSE
      )
    }
  }
  cells <- do.call(rbind, cells)
  rownames(cells) <- NULL

  usable <- cells[cells$available & is.finite(cells$max_acceptable_price), ,
    drop = FALSE
  ]
  best <- list(
    row_label = NA_character_, column_label = NA_character_,
    max_acceptable_price = NA_real_, status = NA_character_
  )
  worst <- best
  if (nrow(usable) > 0L) {
    best_row <- usable[which.max(usable$max_acceptable_price), , drop = FALSE]
    worst_row <- usable[which.min(usable$max_acceptable_price), , drop = FALSE]
    best <- list(
      row_label = best_row$row_label[[1]],
      column_label = best_row$column_label[[1]],
      max_acceptable_price = best_row$max_acceptable_price[[1]],
      status = best_row$status[[1]]
    )
    worst <- list(
      row_label = worst_row$row_label[[1]],
      column_label = worst_row$column_label[[1]],
      max_acceptable_price = worst_row$max_acceptable_price[[1]],
      status = worst_row$status[[1]]
    )
  }

  supported <- sum(cells$price_supported, na.rm = TRUE)
  unavailable_cells <- nrow(cells) - nrow(usable)
  summary <- if (nrow(usable) == 0L) {
    paste0(
      "No assumption combination in the scan could be identified: the model ",
      "did not return a usable maximum acceptable price for any of the ",
      nrow(cells), " combinations."
    )
  } else {
    paste0(
      "Across the scan the maximum acceptable annual price ranges from ",
      eqalb_price_format_money(worst$max_acceptable_price), " (relative risk ",
      "reduction ", worst$row_label, ", year-1 engagement ",
      worst$column_label, ") to ",
      eqalb_price_format_money(best$max_acceptable_price), " (relative risk ",
      "reduction ", best$row_label, ", year-1 engagement ",
      best$column_label, "). ",
      supported, " of ", nrow(cells),
      " combinations support the current annual price of ",
      eqalb_price_format_money(current_price), ".",
      if (unavailable_cells > 0L) {
        paste0(
          " ", unavailable_cells, " combination",
          if (unavailable_cells > 1L) "s" else "",
          " could not be identified and are reported as ",
          EQALB_PRICE_STATUS_NOT_AVAILABLE, "."
        )
      } else {
        ""
      }
    )
  }

  list(
    row_axis = row_axis,
    column_axis = column_axis,
    cells = cells,
    cells_total = nrow(cells),
    cells_available = nrow(usable),
    cells_supporting_current_price = supported,
    best = best,
    worst = worst,
    summary = summary,
    note = paste0(
      "Only the relative risk reduction and year-1 engagement change in this ",
      "scan; every other input, including follow-up engagement, stays at the ",
      "values used for the scenario."
    )
  )
}

# --- Interpretation ----------------------------------------------------------

eqalb_price_headline_interpretation <- function(headline, current_price, wtp,
                                                status) {
  threshold <- eqalb_price_format_threshold(wtp)
  if (identical(status, EQALB_PRICE_STATUS_NOT_AVAILABLE)) {
    return(paste0(
      "A maximum acceptable annual price is not identifiable for these ",
      "assumptions, so the current annual price of ",
      eqalb_price_format_money(current_price), " cannot be compared with the ",
      "reference threshold of ", threshold, ". ", headline$reason
    ))
  }
  if (!isTRUE(headline$available)) {
    heading <- if (identical(status, EQALB_PRICE_STATUS_GREEN)) {
      paste0(
        "At ", threshold, " the model accepts the current annual price of ",
        eqalb_price_format_money(current_price),
        ", but a maximum acceptable price is not reported. "
      )
    } else {
      paste0(
        "The current annual price of ",
        eqalb_price_format_money(current_price),
        " is above what the model supports at ", threshold, ". "
      )
    }
    return(paste0(heading, headline$reason))
  }
  maximum <- eqalb_price_format_money(headline$max_acceptable_price)
  headroom <- abs(headline$max_acceptable_price - current_price)
  # The share of the current price only exists when the current price does; a
  # zero price leaves the percentage undefined, and the sentence reads as a plain
  # amount rather than carrying a placeholder.
  share <- ""
  if (length(headline$headroom_pct) == 1L && is.finite(headline$headroom_pct)) {
    share <- paste0(
      " (", eqalb_price_format_percent(abs(headline$headroom_pct), digits = 1), ")"
    )
  }
  if (identical(status, EQALB_PRICE_STATUS_GREEN)) {
    paste0(
      "At ", threshold, " the model supports an annual price of up to ",
      maximum, " per treated person per year, charged for each year a treated ",
      "person is alive. The current price of ",
      eqalb_price_format_money(current_price), " is ", eqalb_price_format_money(headroom),
      share, " below that level, so it is consistent with the reference ",
      "threshold."
    )
  } else {
    paste0(
      "At ", threshold, " the model supports an annual price of up to ",
      maximum, " per treated person per year, charged for each year a treated ",
      "person is alive. The current price of ",
      eqalb_price_format_money(current_price), " is ", eqalb_price_format_money(headroom),
      share, " above that level, so it does not reach the reference ",
      "threshold."
    )
  }
}

eqalb_price_required_interpretation <- function(required, wtp) {
  threshold <- eqalb_price_format_threshold(wtp)
  if (!isTRUE(required$available)) {
    return(required$reason)
  }
  range <- eqalb_price_sensitivity_range()
  range_text <- paste0(
    eqalb_price_format_share(range$low), " to ",
    eqalb_price_format_share(range$high)
  )
  requirement <- eqalb_price_format_percent(required$required_rrr_pct, digits = 1)
  if (required$required_rrr <= EQALB_PRICE_RRR_MIN) {
    return(paste0(
      "At the current annual price the intervention is already cost-effective ",
      "at ", threshold, " without any relative risk reduction among engaged ",
      "users."
    ))
  }
  paste0(
    "At the current price, the model requires an estimated relative risk ",
    "reduction of ", requirement, " among engaged users to meet ", threshold,
    ". The scenario assumes ",
    eqalb_price_format_share(required$current_rrr),
    if (required$required_rrr <= required$current_rrr) {
      ", which is above that level, so the current assumption is sufficient."
    } else {
      ", which is below that level."
    },
    if (isTRUE(required$within_sensitivity_range)) {
      paste0(
        " The requirement lies inside the model's one-way range of ", range_text,
        " for this input."
      )
    } else {
      paste0(
        " The requirement lies outside the model's one-way range of ", range_text,
        " for this input, so it is more risk reduction than the sensitivity ",
        "analysis explores."
      )
    }
  )
}

# --- Main function -----------------------------------------------------------

# Value-based price analysis for one scenario.
#
# `base_args` is the run_eqalb_model() argument list (as built by scenario_args()
# in api/plumber.R); `wtp` is the reference willingness-to-pay threshold in EUR
# per QALY; `current_price` is the annual intervention price the analysis runs at
# and compares against, and defaults to the scenario's own price.
#
# Returns the price solve, the required relative risk reduction, the 3 x 3
# scan, an availability block and R's interpretation sentences. Every value that
# cannot be identified is returned as NA with the reason in the same object.
calculate_value_based_price <- function(base_args, wtp, current_price = NULL) {
  if (is.null(base_args) || !is.list(base_args)) {
    stop("'base_args' must be the run_eqalb_model() argument list.", call. = FALSE)
  }
  wtp <- suppressWarnings(as.numeric(wtp))
  if (length(wtp) != 1L || is.na(wtp) || !is.finite(wtp) || wtp < 0) {
    stop("'wtp' must be a single non-negative number.", call. = FALSE)
  }

  if (is.null(current_price) || length(current_price) != 1L ||
    is.na(current_price)) {
    current_price <- base_args[["scenario_intervention_price"]]
  }
  current_price <- suppressWarnings(as.numeric(current_price))
  if (length(current_price) != 1L || is.na(current_price) ||
    !is.finite(current_price) || current_price < 0) {
    # Over HTTP the model default always supplies a price; a direct R caller can
    # reach this branch, and it is reported as a missing input rather than
    # guessed.
    return(eqalb_price_missing_price_result(wtp))
  }

  args <- base_args
  args$scenario_intervention_price <- current_price
  scenario_rrr <- args$scenario_rrr
  scenario_engagement <- args$scenario_engagement_year1

  run0 <- eqalb_price_run(args, current_price)
  if (!run0$ok) {
    stop(
      paste("Base-case model failed:", run0$message),
      call. = FALSE
    )
  }

  row_axis <- eqalb_price_axis(args, EQALB_PRICE_GRID_AXES[[1]])
  column_axis <- eqalb_price_axis(args, EQALB_PRICE_GRID_AXES[[2]])

  headline_solve <- eqalb_price_solve(args, wtp, current_price, run0)

  # One solve per assumption pair, cached so the scenario pair (the headline) is
  # computed once and shared with the scan.
  cache <- new.env(parent = emptyenv())
  cache_key <- function(rrr, engagement) {
    paste(format(rrr, digits = 15), format(engagement, digits = 15), sep = "|")
  }
  cache[[cache_key(scenario_rrr, scenario_engagement)]] <- headline_solve
  solve_for <- function(rrr, engagement) {
    key <- cache_key(rrr, engagement)
    if (!is.null(cache[[key]])) {
      return(cache[[key]])
    }
    # The scan cell's own assumptions are used for every run of its solve, so
    # the slope and the verification describe the cell and not the scenario.
    cell_args <- args
    cell_args$scenario_rrr <- rrr
    cell_args$scenario_engagement_year1 <- engagement
    cell_run <- eqalb_price_run(cell_args, current_price)
    solved <- eqalb_price_solve(cell_args, wtp, current_price, cell_run)
    cache[[key]] <- solved
    solved
  }

  grid <- eqalb_price_grid(
    args, wtp, current_price, row_axis, column_axis, solve_for
  )
  required <- eqalb_price_required_rrr(
    args, wtp, current_price, scenario_rrr, run0
  )

  headline <- c(
    headline_solve,
    list(
      headroom_eur = if (isTRUE(headline_solve$available) &&
        is.finite(headline_solve$max_acceptable_price)) {
        headline_solve$max_acceptable_price - current_price
      } else {
        NA_real_
      },
      headroom_pct = if (isTRUE(headline_solve$available) &&
        is.finite(headline_solve$max_acceptable_price) &&
        current_price > 0) {
        100 * (headline_solve$max_acceptable_price - current_price) /
          current_price
      } else {
        NA_real_
      }
    )
  )
  headline$interpretation <- eqalb_price_headline_interpretation(
    headline, current_price, wtp, headline$status
  )
  required$interpretation <- eqalb_price_required_interpretation(required, wtp)

  available_cells <- grid$cells[grid$cells$available, , drop = FALSE]
  availability <- list(
    max_acceptable_price = isTRUE(headline$available),
    required_effect = isTRUE(required$available),
    grid = nrow(available_cells) == grid$cells_total,
    grid_cells_available = nrow(available_cells),
    grid_cells_total = grid$cells_total,
    # Fields the analysis needs and that were not supplied and have no model
    # default. Over HTTP every model input falls back to its base-case constant,
    # so this is empty for every request; it is populated when the function is
    # called directly without an intervention price.
    missing_inputs = character(0),
    reasons = list(
      max_acceptable_price = if (isTRUE(headline$available)) "" else headline$reason,
      required_effect = if (isTRUE(required$available)) "" else required$reason,
      grid = if (nrow(available_cells) == grid$cells_total) {
        ""
      } else {
        paste0(
          nrow(available_cells), " of ", grid$cells_total,
          " scan combinations could be identified."
        )
      }
    )
  )

  list(
    analysis = "value_based_price",
    method = headline$method,
    method_note = EQALB_PRICE_METHOD_NOTE,
    wtp = wtp,
    current_price = current_price,
    scenario = list(
      rrr = scenario_rrr,
      rrr_pct = 100 * scenario_rrr,
      engagement_year1 = scenario_engagement,
      engagement_year1_pct = 100 * scenario_engagement,
      engagement_followup = args$scenario_engagement_followup,
      engagement_followup_pct = 100 * args$scenario_engagement_followup,
      incremental_cost = run0$incremental_cost,
      incremental_qalys = run0$incremental_qalys,
      icer = run0$icer,
      incremental_nmb = eqalb_price_nmb(run0, wtp),
      price_cost_slope = headline$price_cost_slope,
      cost_without_price = headline$cost_without_price,
      price_cost_contribution = run0$price_cost_contribution
    ),
    headline = headline,
    required_effect = required,
    grid = grid,
    availability = availability,
    interpretation = paste(
      headline$interpretation,
      required$interpretation
    ),
    limitation = EQALB_PRICE_LIMITATION,
    status = headline$status
  )
}

# Shape-identical result for a direct R caller that supplied no intervention
# price and no model default to fall back on.
eqalb_price_missing_price_result <- function(wtp) {
  reason <- paste0(
    "No current annual intervention price was supplied, so the analysis cannot ",
    "run. Supply 'current_price' (or 'intervention_price') or pass a model ",
    "argument list that carries 'scenario_intervention_price'."
  )
  list(
    analysis = "value_based_price",
    method = "not_available",
    method_note = EQALB_PRICE_METHOD_NOTE,
    wtp = wtp,
    current_price = NA_real_,
    scenario = list(),
    headline = c(
      eqalb_price_unavailable(reason),
      list(headroom_eur = NA_real_, headroom_pct = NA_real_,
           interpretation = reason)
    ),
    required_effect = list(
      available = FALSE,
      verdict = "not_available",
      verdict_label = eqalb_price_verdict_label("not_available"),
      required_rrr = NA_real_,
      required_rrr_pct = NA_real_,
      current_rrr = NA_real_,
      current_rrr_pct = NA_real_,
      within_sensitivity_range = NA,
      precision_rrr = NA_real_,
      verification_nmb = NA_real_,
      reason = reason,
      interpretation = reason
    ),
    grid = list(
      row_axis = list(),
      column_axis = list(),
      cells = data.frame(),
      cells_total = 0L,
      cells_available = 0L,
      cells_supporting_current_price = 0L,
      best = list(
        row_label = NA_character_, column_label = NA_character_,
        max_acceptable_price = NA_real_, status = NA_character_
      ),
      worst = list(
        row_label = NA_character_, column_label = NA_character_,
        max_acceptable_price = NA_real_, status = NA_character_
      ),
      summary = reason,
      note = ""
    ),
    availability = list(
      max_acceptable_price = FALSE,
      required_effect = FALSE,
      grid = FALSE,
      grid_cells_available = 0L,
      grid_cells_total = 0L,
      missing_inputs = "intervention_price",
      reasons = list(
        max_acceptable_price = reason,
        required_effect = reason,
        grid = reason
      )
    ),
    interpretation = reason,
    limitation = EQALB_PRICE_LIMITATION,
    status = EQALB_PRICE_STATUS_NOT_AVAILABLE
  )
}
